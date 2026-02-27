export type DialogFilter = {
  name: string;
  extensions: string[];
};

export type OpenDialogOptions = {
  title?: string;
  multiple?: boolean;
  directory?: boolean;
  defaultPath?: string;
  filters?: DialogFilter[];
};

export type OpenDialogResult = string | string[] | null;

type TauriDialogApi = {
  open?: (options?: OpenDialogOptions) => Promise<OpenDialogResult>;
};

function fallbackOpen(options: OpenDialogOptions = {}): Promise<OpenDialogResult> {
  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.multiple = Boolean(options.multiple);

    const extensions = (options.filters ?? []).flatMap((filter) =>
      filter.extensions.map((ext) => ext.trim()).filter(Boolean)
    );

    if (extensions.length > 0) {
      input.accept = extensions
        .map((ext) => (ext.startsWith(".") ? ext : `.${ext}`))
        .join(",");
    }

    input.onchange = () => {
      const files = input.files;
      if (!files || files.length === 0) {
        resolve(null);
        return;
      }

      const selected = Array.from(files).map((file) => {
        const maybePath = (file as File & { path?: string }).path;
        return typeof maybePath === "string" && maybePath.length > 0 ? maybePath : file.name;
      });

      resolve(options.multiple ? selected : selected[0]);
    };

    input.click();
  });
}

export async function open(options: OpenDialogOptions = {}): Promise<OpenDialogResult> {
  const tauriDialog = (window as Window & { __TAURI__?: { dialog?: TauriDialogApi } }).__TAURI__?.dialog;

  if (typeof tauriDialog?.open === "function") {
    return tauriDialog.open(options);
  }

  return fallbackOpen(options);
}
