use std::{
    collections::HashMap,
    path::PathBuf,
    sync::{Arc, LazyLock, Mutex},
};

use librqbit::{
    api::{Api, ApiTorrentListOpts, TorrentDetailsResponse, TorrentIdOrHash},
    AddTorrent, AddTorrentOptions, SessionOptions, TorrentStats,
};
use tracing::{info, warn, error};

/// Global, lazily-initialized librqbit session API. flutter_rust_bridge calls
/// are stateless from Dart's perspective, so all state lives here.
static SESSION: Mutex<Option<Arc<Api>>> = Mutex::new(None);

/// Shared map of magnet save-paths that failed or timed out.
/// Key = save_path, Value = error message.
/// Polled by the Dart controller so placeholders can show an error.
static PENDING_ERRORS: LazyLock<Mutex<HashMap<String, String>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

fn api() -> anyhow::Result<Arc<Api>> {
    SESSION
        .lock()
        .map_err(|_| anyhow::anyhow!("session lock poisoned"))?
        .clone()
        .ok_or_else(|| anyhow::anyhow!("torrent session not initialized"))
}

/// Starts the librqbit session. [download_dir] is the default output folder.
/// Also installs a tracing subscriber so `info!`/`warn!`/`error!` logs from
/// librqbit and this module are visible in the Flutter debug console.
#[flutter_rust_bridge::frb]
pub async fn torrent_init(download_dir: String) -> anyhow::Result<()> {
    // Install a tracing subscriber if one isn't already set up.
    // Uses RUST_LOG env var (e.g. RUST_LOG=info,librqbit=debug).
    // Default shows info for our code, debug for librqbit internals, and
    // trace for DHT so peer discovery / query activity is visible.
    let _ = tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| {
                    "info,librqbit=debug,librqbit_dht=trace,librqbit_peer_protocol=debug"
                        .parse()
                        .unwrap()
                }),
        )
        .with_target(true)
        .try_init();

    info!("initializing torrent session with download_dir={}", download_dir);
    let opts = SessionOptions {
        fastresume: true,
        ..Default::default()
    };
    let session = librqbit::Session::new_with_opts(PathBuf::from(&download_dir), opts).await?;
    let api = Api::new(session, None);
    let mut guard = SESSION.lock().map_err(|_| anyhow::anyhow!("lock poisoned"))?;
    *guard = Some(Arc::new(api));
    info!("torrent session initialized successfully");
    Ok(())
}

fn looks_like_url(s: &str) -> bool {
    librqbit::SUPPORTED_SCHEMES.iter().any(|scheme| s.starts_with(scheme))
}

fn is_magnet(s: &str) -> bool {
    s.starts_with("magnet:")
}

/// Adds a torrent from a magnet/URL or a local `.torrent` file path, saving
/// into [save_path]. Returns the new torrent id.
///
/// For magnets, the native add is spawned as an independent tokio task so the
/// Dart side is never blocked.  The torrent appears in `torrent_list` once
/// metadata is resolved by DHT/tracker (typically 5-30 s).
#[flutter_rust_bridge::frb]
pub async fn torrent_add(source: String, save_path: String) -> anyhow::Result<u32> {
    let api = api()?;
    let source = source.trim().to_string();

    if source.is_empty() {
        anyhow::bail!("torrent source is empty");
    }

    let is_magnet_source = is_magnet(&source);

    let add = if is_magnet_source {
        info!("adding torrent from magnet link");
        if !source.contains("xt=urn:btih:") {
            anyhow::bail!(
                "invalid magnet link: must contain xt=urn:btih: parameter"
            );
        }
        AddTorrent::from_url(source)
    } else if looks_like_url(&source) {
        info!("adding torrent from URL: {}", &source);
        AddTorrent::from_url(source)
    } else {
        info!("adding torrent from local file: {}", &source);
        AddTorrent::from_local_filename(&source)?
    };

    let err_path = save_path.clone();
    let opts = AddTorrentOptions {
        output_folder: Some(save_path),
        ..Default::default()
    };

    if is_magnet_source {
        // Spawn the magnet add as a detached tokio task so metadata resolution
        // (DHT / tracker) happens in the background.  The torrent will appear
        // in `torrent_list` once the future completes — the Dart poll loop
        // picks it up automatically.
        info!("spawning background magnet add task");
        let api_clone = api.clone();
        tokio::spawn(async move {
            info!("[magnet] background task started, waiting for metadata...");
            let result = tokio::time::timeout(
                std::time::Duration::from_secs(120),
                api_clone.api_add_torrent(add, Some(opts)),
            )
            .await;

            match result {
                Ok(Ok(resp)) => {
                    let id_str = resp.id.map(|i| i.to_string()).unwrap_or_default();
                    info!("[magnet] background add completed successfully, id={}", id_str);
                }
                Ok(Err(e)) => {
                    error!("[magnet] background add failed: {:#}", e);
                    if let Ok(mut map) = PENDING_ERRORS.lock() {
                        map.insert(err_path, format!("Add failed: {:#}", e));
                    }
                }
                Err(_elapsed) => {
                    warn!(
                        "[magnet] metadata resolution timed out after 120s — \
                         DHT/tracker could not deliver metadata. Check your \
                         network connection, firewall, and ensure DHT port 6881 is open."
                    );
                    if let Ok(mut map) = PENDING_ERRORS.lock() {
                        map.insert(err_path, "Metadata timed out — check network/DHT".into());
                    }
                }
            }
        });
        // Return a sentinel id.  The Dart controller should NOT use this id
        // for pause/resume — it should rely on the poll loop to discover the
        // real torrent id.
        //
        // Use a large id that won't collide with real librqbit ids (which
        // are small sequential numbers).
        let sentinel = u32::MAX - 1;
        info!(
            "magnet add spawned in background; sentinel id={} returned",
            sentinel
        );
        Ok(sentinel)
    } else {
        let resp = api.api_add_torrent(add, Some(opts)).await?;
        let id = resp
            .id
            .ok_or_else(|| anyhow::anyhow!("torrent was not assigned an id"))?;
        info!("torrent added successfully with id={}", id);
        Ok(id as u32)
    }
}

/// Lists all torrents with their current stats.
#[flutter_rust_bridge::frb]
pub async fn torrent_list() -> anyhow::Result<Vec<TorrentSnapshot>> {
    let api = api()?;
    let response = api.api_torrent_list_ext(ApiTorrentListOpts { with_stats: false });
    let mut out = Vec::with_capacity(response.torrents.len());
    for details in response.torrents {
        if let Some(id) = details.id {
            out.push(snapshot_for(&api, id, &details));
        }
    }
    Ok(out)
}

/// Returns any pending magnet errors (timeout or add failure), keyed by
/// save_path.  The caller should clear entries after handling them.
#[flutter_rust_bridge::frb]
pub async fn torrent_pending_errors() -> anyhow::Result<Vec<TorrentError>> {
    let mut map = PENDING_ERRORS
        .lock()
        .map_err(|_| anyhow::anyhow!("pending_errors lock poisoned"))?;
    let out: Vec<TorrentError> = map
        .drain()
        .map(|(path, message)| TorrentError {
            save_path: path,
            message,
        })
        .collect();
    Ok(out)
}

/// A magnet that failed to resolve metadata.
pub struct TorrentError {
    pub save_path: String,
    pub message: String,
}

/// Returns the current stats for a single torrent id.
#[flutter_rust_bridge::frb]
pub async fn torrent_stats(id: u32) -> anyhow::Result<TorrentSnapshot> {
    let api = api()?;
    let idx = TorrentIdOrHash::Id(id as usize);
    let details = api.api_torrent_details(idx)?;
    Ok(snapshot_for(&api, id as usize, &details))
}

/// Lists the files contained in a torrent (empty until metadata arrives).
/// Synchronous because it only reads in-memory metadata.
#[flutter_rust_bridge::frb(sync)]
pub fn torrent_files(id: u32) -> anyhow::Result<Vec<TorrentFileInfo>> {
    let api = api()?;
    let details = api.api_torrent_details(TorrentIdOrHash::Id(id as usize))?;
    Ok(file_infos(&details))
}

#[flutter_rust_bridge::frb]
pub async fn torrent_pause(id: u32) -> anyhow::Result<()> {
    let api = api()?;
    api.api_torrent_action_pause(TorrentIdOrHash::Id(id as usize))
        .await?;
    Ok(())
}

#[flutter_rust_bridge::frb]
pub async fn torrent_resume(id: u32) -> anyhow::Result<()> {
    let api = api()?;
    api.api_torrent_action_start(TorrentIdOrHash::Id(id as usize))
        .await?;
    Ok(())
}

/// Removes a torrent. When [delete_files] is true the downloaded data is also
/// deleted from disk; otherwise the torrent is just forgotten from the session.
#[flutter_rust_bridge::frb]
pub async fn torrent_delete(id: u32, delete_files: bool) -> anyhow::Result<()> {
    let api = api()?;
    let idx = TorrentIdOrHash::Id(id as usize);
    if delete_files {
        api.api_torrent_action_delete(idx).await?;
    } else {
        api.api_torrent_action_forget(idx).await?;
    }
    Ok(())
}

fn is_paused(stats: &TorrentStats) -> bool {
    match &stats.state {
        librqbit::TorrentStatsState::Initializing { paused } => *paused,
        librqbit::TorrentStatsState::Paused => true,
        librqbit::TorrentStatsState::Live | librqbit::TorrentStatsState::Error => false,
    }
}

fn build_status_string(stats: Option<&TorrentStats>, is_paused: bool, is_finished: bool, has_metadata: bool) -> String {
    if let Some(stats) = stats {
        if stats.error.is_some() {
            return "error".to_string();
        }
    }
    if is_paused {
        return "paused".to_string();
    }
    if is_finished {
        return "seeding".to_string();
    }
    if !has_metadata {
        return "fetchingMetadata".to_string();
    }
    "downloading".to_string()
}

fn snapshot_for(api: &Api, id: usize, details: &TorrentDetailsResponse) -> TorrentSnapshot {
    let stats = api
        .api_stats_v1(TorrentIdOrHash::Id(id))
        .ok();
    build_snapshot(details, stats.as_ref())
}

fn build_snapshot(details: &TorrentDetailsResponse, stats: Option<&TorrentStats>) -> TorrentSnapshot {
    let (is_paused, is_finished, has_metadata, progress, download_rate, upload_rate, error_msg, num_peers) =
        if let Some(stats) = stats {
            let is_paused = is_paused(stats);
            let is_finished = stats.finished;
            let has_metadata = stats.total_bytes > 0;
            let progress = if stats.total_bytes == 0 {
                0.0
            } else {
                stats.progress_bytes as f64 / stats.total_bytes as f64
            };
            let (download_rate, upload_rate, num_peers) =
                if let Some(live) = &stats.live {
                    (
                        live.download_speed.as_bytes() as i64,
                        live.upload_speed.as_bytes() as i64,
                        live.snapshot.peer_stats.live,
                    )
                } else {
                    (0, 0, 0)
                };
            (
                is_paused,
                is_finished,
                has_metadata,
                progress,
                download_rate,
                upload_rate,
                stats.error.clone().unwrap_or_default(),
                num_peers,
            )
        } else {
            // Fallback when stats unavailable: treat as downloading from details.
            (false, false, false, 0.0, 0, 0, String::new(), 0)
        };

    TorrentSnapshot {
        id: details.id.unwrap_or_default() as u32,
        name: details.name.clone().unwrap_or_else(|| "Fetching metadata…".to_string()),
        save_path: details.output_folder.clone(),
        error_msg,
        status: build_status_string(stats, is_paused, is_finished, has_metadata),
        progress,
        download_rate,
        upload_rate,
        total_done: stats.map(|s| s.progress_bytes as i64).unwrap_or(0),
        total_wanted: stats.map(|s| s.total_bytes as i64).unwrap_or(0),
        total_uploaded: stats.map(|s| s.uploaded_bytes as i64).unwrap_or(0),
        num_peers,
        num_seeds: 0,
        is_paused,
        is_finished,
        has_metadata,
    }
}

fn file_infos(details: &TorrentDetailsResponse) -> Vec<TorrentFileInfo> {
    let mut out = Vec::new();
    if let Some(files) = &details.files {
        for (index, f) in files.iter().enumerate() {
            out.push(TorrentFileInfo {
                index: index as u32,
                name: f.name.clone(),
                path: f.components.join("/"),
                size: f.length as i64,
            });
        }
    }
    out
}

/// A single torrent's state, mirroring what the old UI consumed.
pub struct TorrentSnapshot {
    pub id: u32,
    pub name: String,
    pub save_path: String,
    pub error_msg: String,
    pub status: String,
    pub progress: f64,
    pub download_rate: i64,
    pub upload_rate: i64,
    pub total_done: i64,
    pub total_wanted: i64,
    pub total_uploaded: i64,
    pub num_peers: u32,
    pub num_seeds: u32,
    pub is_paused: bool,
    pub is_finished: bool,
    pub has_metadata: bool,
}

/// A single file inside a torrent.
pub struct TorrentFileInfo {
    pub index: u32,
    pub name: String,
    pub path: String,
    pub size: i64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn init_and_list_runs_without_error() {
        let dir = std::env::temp_dir().join(format!("rqbit_smoke_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        torrent_init(dir.to_string_lossy().into_owned())
            .await
            .unwrap();
        // Fresh session: no torrents yet, but listing must not error.
        assert!(torrent_list().await.unwrap().is_empty());
        let _ = std::fs::remove_dir_all(&dir);
    }
}
