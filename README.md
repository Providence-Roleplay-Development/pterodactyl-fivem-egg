<div align="center">
  <h1>FiveM/RedM Server Egg</h1>

  <em>
    A custom Pterodactyl egg for <a href="https://fivem.net/">FiveM</a> & <a href="https://redm.net/">RedM</a> 
    designed by the <strong>Providence Roleplay Development Team</strong> — featuring automatic artifact updates 
    and multi-repository git synchronization.
  </em>

  <br><br>

---

## 🌟 Features

- Easy server artifact updating using the **Reinstall** button.  
- Full **Git support** — clone and pull server files from **multiple repositories** into designated folders (e.g. `/resources`, `/data`, or other custom paths).  
- **TxAdmin support** for advanced server management.  
- Automatic artifact downloads for *latest*, *recommended*, or *specific version numbers*.  

> This egg is a custom version of [milkdrinkers/pterodactyl-fivem-egg](https://github.com/milkdrinkers/pterodactyl-fivem-egg), enhanced by Providence Roleplay Development Team to support multiple git repositories.

---

## ❓ FAQ

> **Why create this fork?**  
>  
> The standard FiveM egg didn’t support multiple git repositories. We needed a version that automatically synchronizes multiple private repos across server startup and reinstall events.

> **Why use this egg?**  
>  
> It retains all the original features while adding multi-repo support, enabling teams to keep resources, scripts, and configs synced in separate repositories.

> **Who maintains this version?**  
>  
> The **Providence Roleplay Development Team**, based on the original milkdrinkers version.

---

## 📦 Guides

### Updating Server Artifact

To update your server’s artifact:

1. On your server’s **Startup** page, set the `FXServer Version` to one of the following:
   - `latest` — Downloads the latest available artifact.  
   - `recommended` — Downloads the recommended artifact.  
   - Specific version number (e.g. `25770`) — Downloads that version.

2. On your server’s **Settings** page, click **Reinstall Server** and wait for the artifact update to complete.  

> ⚠️ The `/alpine/` directory will be replaced with the new artifact.

---

### Multi-Repo Git Auto Update

Behavior when Git is enabled:

#### Startup Scenarios
- If a configured folder (e.g. `/resources`, `/data`) is empty, the specified repository will be **cloned** on startup.  
- If a folder already contains a `.git` repository, it will automatically **pull** the latest changes.  

#### Reinstall Scenarios
- Missing directories are recreated and cloned from their respective repositories after reinstall.  

> You can define multiple repository URLs and target folders using custom environment variables before server startup.

---

## 🛠️ Server Ports

| Type | Port |
| - | - |
| Game | 30120 |
| txAdmin | 40120 (*Optional*) |

---

## ❤️ Acknowledgments

- **[Parkervcp](https://github.com/parkervcp)** – For the original [FiveM egg](https://github.com/pelican-eggs/games-standalone/blob/main/gta/fivem).  
- **[Milkdrinkers](https://github.com/milkdrinkers/pterodactyl-fivem-egg)** – For the base egg implementation.  
- **[Pterodactyl](https://pterodactyl.io/)** – For developing the panel used to host this system.  
- **[Cfx.re](https://fivem.net/)** – For creating and maintaining FiveM & RedM.  
- **Providence Roleplay Development Team** – For extending git support to multiple repositories and automating updates.

---