#!/usr/bin/env node



const { spawnSync } = require("node:child_process");
const path = require("node:path");

const args = process.argv.slice(2);

if (args.length === 0 || args[0] === "--help") {
    console.log(`
Create a TSOA project.

Usage:
  npx tsoa_generate <project-path>

Examples:
  npx tsoa_generate my-api
  npx tsoa_generate ./projects/my-api
  npx tsoa_generate "C:\\Projects\\my-api"
`);
    process.exit(args[0] === "--help" ? 0 : 1);
}

const platform = process.platform;

const scriptsDirectory = path.join(__dirname, "..", "scripts");

let command;
let commandArgs;

if (platform === "win32") {
    console.log("Detected Windows. Running PowerShell installer.");

    command = "powershell.exe";

    commandArgs = [
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        path.join(scriptsDirectory, "windows.ps1"),
        ...args
    ];
} else if (platform === "linux" || platform === "darwin") {
    console.log("Detected Unix-based OS. Running Bash installer.");

    command = "bash";

    commandArgs = [
        path.join(scriptsDirectory, "unix.sh"),
        ...args
    ];
} else {
    console.error(`Unsupported operating system: ${platform}`);
    process.exit(1);
}

const result = spawnSync(command, commandArgs, {
    stdio: "inherit",
    cwd: process.cwd(),
    windowsHide: false
});

if (result.error) {
    console.error("Failed to execute installer:", result.error.message);
    process.exit(1);
}

process.exit(result.status ?? 1);
