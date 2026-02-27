import { useState } from "react";
import { open } from "@tauri-apps/plugin-dialog";
import { openPath } from "@tauri-apps/plugin-opener";
import { runAnalysis } from "../services/cliService";

type LogTab = "stdout" | "stderr";

type ErrorWithStreams = Error & {
  stderr?: unknown;
  stdout?: unknown;
};

function asNonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

export default function NewAnalysis() {
  const [inputPath, setInputPath] = useState("");
  const [stdout, setStdout] = useState("");
  const [stderr, setStderr] = useState("");
  const [activeTab, setActiveTab] = useState<LogTab>("stdout");

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [reportPath, setReportPath] = useState("");
  const [vaultPath, setVaultPath] = useState("");

  const selectJsonFile = async () => {
    try {
      const selected = await open({
        multiple: false,
        directory: false,
        filters: [{ name: "JSON", extensions: ["json"] }]
      });

      if (!selected) {
        setInputPath("");
        return;
      }

      if (typeof selected === "string") {
        setInputPath(selected);
        return;
      }

      if (Array.isArray(selected)) {
        const first = selected[0];
        if (typeof first === "string") {
          setInputPath(first);
        }
        return;
      }

      setInputPath("");
    } catch (e) {
      console.error("Dialog error:", e);
      setError("File picker failed (permissions/config).");
    }
  };

  const handleRunAnalysis = async () => {
    if (!inputPath) return;

    setLoading(true);
    setError("");
    setStdout("");
    setStderr("");
    setReportPath("");
    setVaultPath("");
    setActiveTab("stdout");

    try {
      const result = await runAnalysis(inputPath);
      setStdout(result.stdout);
      setReportPath(result.report_path);
      setVaultPath(result.vault_path);
    } catch (err: unknown) {
      console.error("Run analysis error:", err);

      const e = err as ErrorWithStreams;
      const msg =
        err instanceof Error && err.message.trim().length > 0
          ? err.message
          : "Analysis failed";
      const stderrMsg = asNonEmptyString(e.stderr) ?? asNonEmptyString(e.stdout) ?? msg;

      setError(msg);
      setStderr(stderrMsg);
      setActiveTab("stderr");
    } finally {
      setLoading(false);
    }
  };

  const canOpenReport = Boolean(reportPath);
  const canOpenVault = Boolean(vaultPath);

  const handleOpenFinalReport = async () => {
    if (!reportPath) return;

    console.log("Report path being opened:", reportPath);

    try {
      await openPath(reportPath);
    } catch (e) {
      console.error("Open report error:", e);
      const msg = e instanceof Error ? e.message : "Could not open final report.";
      setError(msg);
    }
  };

  const handleOpenVaultFolder = async () => {
    if (!vaultPath) return;

    console.log("Vault path being opened:", vaultPath);

    try {
      await openPath(vaultPath);
    } catch (e) {
      console.error("Open vault error:", e);
      const msg = e instanceof Error ? e.message : "Could not open vault folder.";
      setError(msg);
    }
  };

  return (
    <div className="dv-page">
      <div className="dv-page__header">
        <div>
          <h1 className="dv-h1">New Analysis</h1>
          <p className="dv-subtitle">
            Select a JSON input file and execute the deterministic analysis pipeline.
          </p>
        </div>
      </div>

      <div className="dv-grid">
        {/* LEFT: INPUT */}
        <section className="dv-card">
          <div className="dv-card__top">
            <div>
              <div className="dv-card__kicker">INPUT</div>
              <div className="dv-card__title">Analysis Source File</div>
            </div>
          </div>

          <div className="dv-divider" />

          <div className="dv-actions">
            <button className="dv-btn dv-btn--primary" onClick={selectJsonFile} type="button">
              Select JSON File
            </button>

            <button
              className="dv-btn"
              disabled={!inputPath || loading}
              onClick={handleRunAnalysis}
              type="button"
            >
              {loading ? "Running..." : "Run Analysis"}
            </button>
          </div>

          <div className="dv-divider" />

          <label className="dv-label">Selected File Path</label>
          <pre
            className="dv-log dv-mono"
            style={{ minHeight: 96, whiteSpace: "pre-wrap", wordBreak: "break-all" }}
          >
            {inputPath || "No file selected"}
          </pre>

          <div className="dv-divider dv-divider--spaced" />

          <div className="dv-actions">
            <button
              className="dv-btn"
              disabled={!canOpenReport}
              onClick={handleOpenFinalReport}
              type="button"
            >
              Open Final Report
            </button>

            <button
              className="dv-btn"
              disabled={!canOpenVault}
              onClick={handleOpenVaultFolder}
              type="button"
            >
              Open Vault Folder
            </button>
          </div>

          {error && (
            <>
              <div className="dv-divider" />
              <div className="dv-banner dv-banner--danger">{error}</div>
            </>
          )}
        </section>

        {/* RIGHT: LOGS */}
        <section className="dv-card dv-card--logs">
          <div className="dv-logs__header">
            <div className="dv-card__title" style={{ marginTop: 0 }}>
              Raw Execution Log
            </div>

            <div className="dv-logs__tabs">
              <button
                className={`dv-tab ${activeTab === "stdout" ? "dv-tab--active" : ""}`}
                onClick={() => setActiveTab("stdout")}
                type="button"
              >
                STDOUT
              </button>

              <button
                className={`dv-tab dv-tab--danger ${activeTab === "stderr" ? "dv-tab--active" : ""}`}
                onClick={() => setActiveTab("stderr")}
                type="button"
              >
                STDERR
              </button>
            </div>

            <div className="dv-logs__tools" />
          </div>

          <div className="dv-divider" />

          <pre className="dv-log dv-mono">
            {activeTab === "stdout" ? stdout || "No logs yet." : stderr || "No stderr output."}
          </pre>
        </section>
      </div>
    </div>
  );
}
