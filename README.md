# dotnetvite.ps1

This PowerShell script automates the setup of a modern ASP.NET MVC project integrated with [Vite](https://vitejs.dev/) as the frontend build tool. It allows you to quickly scaffold a .NET MVC application with your choice of frontend frameworks (React, Vue, Svelte, Angular, etc.), and automatically wires up the Vite dev/build process with .NET's static file serving.

---

## Features

- **Interactive setup:** Prompts for your project name and framework choices.
- **Frontend integration:** Supports major frameworks like React, Vue, Svelte, Angular, Solid, Preact, Qwik, Marko, Vanilla JS/TS, and more.
- **Automatic Vite configuration:** Sets up Vite with the correct plugins, directory structure, and build output.
- **.NET MVC enhancements:** Modifies controllers, views, and adds helpers for Vite asset management.
- **Scaffolds boilerplate:** Generates navigation, layout, starter pages, and example API endpoints.
- **Angular special handling:** Supports Angular CLI, zone.js configuration, CSS preprocessors, and SSR/SSG.
- **Cross-platform:** Designed for use on Windows with PowerShell.

---

## Prerequisites

- [.NET SDK 7+](https://dotnet.microsoft.com/download)
- [Node.js & npm](https://nodejs.org/)
- [PowerShell](https://docs.microsoft.com/en-us/powershell/)

For Angular projects, [Angular CLI](https://angular.io/cli) will be installed if not present.

---

## Usage

1. **Download the script:**

   - [Download dotnetvite.ps1](https://github.com/fussionlab/dotnetvite/blob/main/dotnetvite.ps1)
   - Or clone this repository:
     ```sh
     git clone https://github.com/fussionlab/dotnetvite.git
     cd dotnetvite
     ```

2. **Run the script in PowerShell:**

   ```powershell
   # Optionally, set the execution policy to allow script running
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ./dotnetvite.ps1
   ```

3. **Follow the prompts:**

   - Enter your project name.
   - Select the frontend framework and variant (e.g., React + TypeScript).
   - For Angular, answer additional configuration questions.

4. **Wait for the script to scaffold your project.**
   - The script will generate the ASP.NET MVC app, configure Vite, install dependencies, and set up the frontend.

5. **Start development servers:**

   In two terminals:

   - **.NET backend:**
     ```sh
     dotnet run
     ```
   - **Frontend (Vite):**
     ```sh
     cd ClientApp
     npm run dev
     ```

---

## Project Structure

```
YourProject/
├── Controllers/
├── Models/
├── Views/
├── Helpers/
│   └── ViteManifest.cs
├── ClientApp/
│   ├── src/
│   ├── public/
│   ├── vite.config.js|ts
│   └── ...
├── Program.cs
├── YourProject.csproj
└── ...
```

---

## Supported Frontend Frameworks

- **React** (JavaScript, TypeScript, SWC)
- **Vue**
- **Svelte**
- **Solid**
- **Preact**
- **Qwik**
- **Marko**
- **Lit**
- **Angular**
- **Vanilla JS/TS**

---

## How it works

- The script generates a new ASP.NET MVC project and adjusts controllers, layout, and view files to enable seamless integration with Vite.
- It scaffolds the frontend in the `ClientApp` folder using your selected framework and configures Vite for HMR (hot module replacement) during development.
- A helper (`ViteManifest.cs`) is used to load built JS/CSS chunks in production.
- MVC views are set up to correctly include Vite assets in both development and production.

---

## Notes & Tips

- The script is intended for **new projects**. You may adapt it for existing projects, but review the file operations carefully.
- For Angular, additional questions allow you to customize zone.js, SSR, and CSS preprocessors.
- On first run, dependencies are installed automatically. You can re-run `npm install` in `ClientApp` later as needed.

---

## Troubleshooting

- If you see permission errors running the script, try launching PowerShell as Administrator or adjust your execution policy:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
  ```
- For Angular CLI install errors, try restarting your terminal after install.

---

## License

MIT

---

## Credits

- Inspired by [Vite](https://vitejs.dev/) and [ASP.NET Core](https://dotnet.microsoft.com/).
- Script by [@fussionlab](https://github.com/fussionlab).

---

## Contributing

PRs and suggestions are welcome! Please open issues or pull requests on [GitHub](https://github.com/fussionlab/dotnetvite).
