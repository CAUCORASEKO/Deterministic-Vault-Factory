import { Outlet } from "react-router-dom";
import Sidebar from "./Sidebar";

export default function MainLayout() {
  return (
    <div style={styles.appShell}>
      <Sidebar />

      <div style={styles.contentArea}>
        <header style={styles.topBar}>
          <div>
            <div style={styles.appTitle}>Deterministic Vault</div>
            <div style={styles.subtitle}>
              Institutional Risk Evidence Workstation
            </div>
          </div>

          <div style={styles.statusBlock}>
            <div style={styles.statusIndicator} />
            <div>
              <div style={styles.statusText}>Engine Online</div>
              <div style={styles.metaText}>
                UTC {new Date().toISOString().slice(0, 19).replace("T", " ")}
              </div>
            </div>
          </div>
        </header>

        <main style={styles.mainContent}>
          <Outlet />
        </main>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  appShell: {
    display: "flex",
    height: "100vh",
    backgroundColor: "#0F172A",
    color: "#F8FAFC",
    fontFamily: "Inter, system-ui, sans-serif"
  },
  contentArea: {
    flex: 1,
    display: "flex",
    flexDirection: "column"
  },
  topBar: {
    height: "80px",
    backgroundColor: "#1E293B",
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "0 32px",
    borderBottom: "1px solid #334155"
  },
  appTitle: {
    fontSize: "20px",
    fontWeight: 600
  },
  subtitle: {
    fontSize: "12px",
    color: "#94A3B8",
    marginTop: "4px"
  },
  statusBlock: {
    display: "flex",
    alignItems: "center",
    gap: "12px"
  },
  statusIndicator: {
    width: "10px",
    height: "10px",
    borderRadius: "50%",
    backgroundColor: "#16A34A"
  },
  statusText: {
    fontSize: "14px",
    fontWeight: 500
  },
  metaText: {
    fontSize: "11px",
    color: "#94A3B8"
  },
  mainContent: {
    flex: 1,
    padding: "40px",
    backgroundColor: "#0F172A",
    overflow: "auto"
  }
};