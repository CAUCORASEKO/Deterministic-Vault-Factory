import { Navigate, Route, Routes } from 'react-router-dom';
import MainLayout from './layout/MainLayout';
import Dashboard from './pages/Dashboard';
import NewAnalysis from './pages/NewAnalysis';
import Vault from './pages/Vault';
import EvidencePackages from './pages/EvidencePackages';
import VerifyPackage from './pages/VerifyPackage';
import Settings from './pages/Settings';

export default function App() {
  return (
    <Routes>
      <Route element={<MainLayout />}>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/new-analysis" element={<NewAnalysis />} />
        <Route path="/vault" element={<Vault />} />
        <Route path="/evidence-packages" element={<EvidencePackages />} />
        <Route path="/verify-package" element={<VerifyPackage />} />
        <Route path="/settings" element={<Settings />} />
      </Route>
    </Routes>
  );
}
