#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(serde::Serialize)]
struct AnalysisResult {
  stdout: String,
  report_path: String,
  vault_path: String,
}

fn project_root() -> Result<PathBuf, String> {
  let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
  let desktop_app_dir = manifest_dir
    .parent()
    .ok_or_else(|| "Failed to resolve desktop-app directory".to_string())?;
  let project_root = desktop_app_dir
    .parent()
    .ok_or_else(|| "Failed to resolve project root directory".to_string())?;
  Ok(project_root.to_path_buf())
}

fn run_script(script_rel_path: &str, args: &[String]) -> Result<String, String> {
  let root = project_root()?;
  let script_path = root.join(script_rel_path);

  let output = Command::new(&script_path)
    .args(args)
    .current_dir(&root)
    .output()
    .map_err(|err| format!("Failed to execute {:?}: {}", script_path, err))?;

  let stdout = String::from_utf8_lossy(&output.stdout).to_string();
  let stderr = String::from_utf8_lossy(&output.stderr).to_string();

  if output.status.success() {
    Ok(stdout)
  } else {
    let combined = format!("{}\n{}", stdout, stderr).trim().to_string();
    Err(if combined.is_empty() {
      "Unknown error".to_string()
    } else {
      combined
    })
  }
}

fn extract_path(stdout: &str, prefix: &str) -> String {
  stdout
    .lines()
    .find_map(|line| {
      line.find(prefix)
        .map(|index| line[index + prefix.len()..].trim().to_string())
    })
    .unwrap_or_default()
}

fn to_absolute_path(root: &Path, maybe_relative: &str) -> String {
  if maybe_relative.trim().is_empty() {
    return String::new();
  }

  let candidate = PathBuf::from(maybe_relative.trim());
  if candidate.is_absolute() {
    candidate.to_string_lossy().to_string()
  } else {
    root.join(candidate).to_string_lossy().to_string()
  }
}

#[tauri::command]
fn build_package(hash: String) -> Result<String, String> {
  run_script("engine/evidence/tools/build_package.sh", &[hash])
}

#[tauri::command]
fn verify_package(zip_path: String) -> Result<String, String> {
  run_script("engine/evidence/tools/verify_package.sh", &[zip_path])
}

#[tauri::command]
fn run_analysis(input_path: String) -> Result<AnalysisResult, String> {
  let stdout = run_script("engine/pipelines/run_analysis.sh", &[input_path])?;
  let root = project_root()?;

  let report_rel = extract_path(&stdout, "Final report written to ");
  let vault_rel = extract_path(&stdout, "Evidence archived to ");

  Ok(AnalysisResult {
    stdout,
    report_path: to_absolute_path(&root, &report_rel),
    vault_path: to_absolute_path(&root, &vault_rel),
  })
}

#[tauri::command]
fn get_cwd() -> Result<String, String> {
  std::env::current_dir()
    .map(|p| p.display().to_string())
    .map_err(|e| e.to_string())
}

fn main() {
  tauri::Builder::default()
    .plugin(tauri_plugin_dialog::init())
    .plugin(tauri_plugin_opener::init())
    .invoke_handler(
      tauri::generate_handler![
        build_package,
        verify_package,
        run_analysis,
        get_cwd
      ]
    )
    .run(tauri::generate_context!())
    .expect("error while running tauri application");
}
