export const getEnv = (key: string, defaultValue: string): string => {
  const val = (window as any).__env__?.[key];
  if (val && typeof val === "string" && !val.startsWith("$") && !val.includes("${") && val.trim() !== "") {
    return val;
  }
  return defaultValue;
};

export const getFirebaseConfig = (): Record<string, any> => {
  const val = (window as any).__env__?.VITE_APP_FIREBASE_CONFIG;
  const defaultValue = import.meta.env.VITE_APP_FIREBASE_CONFIG;
  let configStr = defaultValue;
  if (val && typeof val === "string" && !val.startsWith("$") && !val.includes("${") && val.trim() !== "") {
    configStr = val;
  }
  try {
    return JSON.parse(configStr);
  } catch (error: any) {
    console.warn(
      `Error JSON parsing firebase config. Supplied value: ${configStr}`,
      error
    );
    return {};
  }
};
