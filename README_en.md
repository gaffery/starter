# Wish Tool Documentation

[中文版](./README.md)

---

## Table of Contents
+ [Quick Start](#quick-start)
+ [Basic Usage](#basic-usage)
+ [Command Guide](#command-guide)
+ [Launcher Guide](#launcher-guide)
+ [Dependencies](#dependencies)
+ [Environment Variables](#environment-variables)
+ [FAQ](#faq)
+ [Contributing Guide](#contributing-guide)

---

## Quick Start

Download the release package for your platform and extract it to any directory. Simply run the launcher or wish script in the directory (you can configure or modify environment variables in the startup script to specify different cache or development directories).

With simple commands, you can quickly synchronize software, plugins, tools, scripts, Python modules, etc. from the framework to your local device, and directly launch or execute them.

### What can it do?
- One-click launch of software or tools, no manual download or installation required
- Quickly build Python versions and third-party library environments, and run scripts directly
- Easily switch between multiple project environments, each with independent configuration and dependencies
- Automatically manage dependencies and development environments, parse upstream/downstream relationships via API, and support developer mode

## Basic Usage
Enter the command in cmd or terminal: wish xxx - yyy (xxx is the package name, yyy is the command to execute)
- Example: Cache and launch Blender for the first time, then quickly launch from cache:
  ![Demo 1](./images/cmd_7aTg34G0no.gif)
- Example: Launch the GUI launcher, showing login, project info, and launcher icons:
  ![Demo 2](./images/cmd_GAeZxGuQdr.gif)
- Example: Switch between different Python versions and libraries, no need to manually install multiple Pythons or pip:
  ![Demo 3](./images/cmd_yzO16Lb4nP.gif)
- Example: One-click start of large model proxy environment and MCP service:
  ![Demo 4](./images/cmd_Poy8AqLRwB.gif)
- Example: Quickly start Maya and auto-license (for learning/testing only), different projects can load different environments and tools:
  ![Demo 5](./images/explorer_cPLMkS9TOh.gif)
- Example: Start Maya and load Arnold renderer, simplified workflow, plugin auto-adapts to Maya2025:
  ![Demo Maya Plugin](./images/python_2d8mYHd35f.gif)

In summary, Wish uses a caching mechanism to automatically isolate and manage runtime environments, improving consistency and automation efficiency. It is suitable for clusters, automation, and other scenarios without pre-deploying environments. Different projects can automatically initialize independent environments, and the cache can record access and support custom cleanup strategies.

### Command Format

wish <package>(required)[@path(optional)]=tag(optional) - command(optional)
- `package`: can specify multiple packages (required)
- `command`: command to execute after requesting the package
- `@path`: specify local package path (for debugging, optional)
- `=tag`: specify version selection rule (optional)
- `-command`: command to execute (optional)

#### Usage Examples
- `wish python=3.7 requests - python`
  
  Request Python 3.7, requests matches the latest version for Python 3.7, then launch the Python interpreter
- `wish python=3.10 requests>=2.32 - python`
  
  Request Python 3.10, requests matches the latest version >=2.32, then launch the Python interpreter
- `wish wish + start`

#### Path Syntax
- `@` can specify a package outside the cache directory (for debugging, optional)
#### Tag Syntax
- `=` match latest minor version (default)
- `<` less than a version
- `>` greater than a version
- `<=` less than or equal to
- `>=` greater than or equal to
- `==` exact version
- `!=` exclude a version
#### Command Execution Syntax
- `-` simple info mode (show only cache info)
- `+` verbose mode (show detailed execution info)

### Launch the default GUI launcher
![Default Launcher](./images/launcher1.png)
![User Demo](./images/python_cd29wKqk9h.gif)

## Command Guide
Wish is a highly efficient and concise command-line dependency cache executor. It automatically caches required packages and their dependencies, and immediately executes specified commands to help you quickly enter your development or runtime environment.

### Core Principles & Workflow
Wish enables automated environment configuration and task execution through command-based package requests and dependency management. The main workflow is as follows:

1. **Package Lookup & Caching**:
   - When a user requests a package via the wish command, Wish searches the local cache and API database based on package name, tag, path, etc.
   - If the local cache is inconsistent with the cloud, it will auto-update; otherwise, it uses the local cache directly.
   - Supports @path to specify a local package path for debugging and local development.
2. **Package Structure & Identification**:
   - Any directory containing package.py is considered a package.
   - The current directory is the package version (tags), and the parent directory is the package name.
   - After matching a package, its package.py is executed automatically.
3. **Dependency Parsing & Reverse Execution**:
   - Wish parses dependencies (req), platform compatibility (ava), optional extensions (ext), exclusion rules (ban), etc.
   - Dependency packages' package.py files are executed in reverse order to ensure dependencies are configured first.
4. **Environment Variables & Command Execution**:
   - package.py supports simplified environment variable configuration (e.g., env("PATH").insert(...)).
   - Wish supports specifying commands with - or +, automatically entering the package environment and executing (+ for verbose output), and can configure aliases via alias.
   - Supports nested execution, e.g., wish python=3.10 - wish python=2.7 - python.
5. **Automation & Integration**:
   - Wish integrates package management, environment configuration, dependency parsing, and command execution, greatly improving automation efficiency.

### package.py Mechanism & Example
Wish uses package.py for custom configuration, dependency declaration, and environment variable management. Each package's package.py is executed automatically when the package is requested.

#### 1. Purpose of package.py
- Declare applicable platforms, dependencies, exclusion rules, etc.
- Configure environment variables such as PATH, LD_LIBRARY_PATH, etc.
- Run arbitrary Python code for flexible initialization logic

#### 2. Common Functions
- `this`: package info methods
   - `this.root`: current package directory path
   - `this.name`: current package name
   - `this.tags`: current package tags
   - `this.init`: initialization status (True on first execution)
- `env`: environment variable management
   - `env("PATH").setenv(path)`: set environment variable (overwrite)
   - `env("PATH").insert(path)`: insert path at the front
   - `env("PATH").append(path)`: insert path at the end
   - `env("PATH").remove(path)`: remove specified path
   - `env("PATH").unload(path)`: remove path by prefix
   - `env("PATH").envlist()`: get PATH as a list
   - `env("PATH").getenv()`: get PATH as a string
   - `env("PATH").unset()`: unset PATH variable
- `ava("platform=win32")`: declare platform
- `req("python>=3.10")`: declare dependency
- `ext("pyside2=5.15.2")`: declare extension
- `ban("numpy==1.24.0")`: exclude package
- `alias("test", "python xxxx.py")`: define alias

#### 3. Example
```python
import os
ava("platform=win32")
req("python>=3.10")
# ban("numpy==1.24.0")
cmd_path = os.path.join(this.root, "src", "cmd")
env("PATH").insert(cmd_path)
```

#### 4. Execution Flow
- Wish parses the command and automatically finds and caches the package
- Dependency packages' package.py files are executed in reverse order, then the main package
- Use wish - or wish + to specify a command, automatically enter the package environment and execute

#### 5. Advanced Usage
- Multiple dependencies and nested execution: `wish python=3.10 - wish toolset=latest - python`
- Local development package: `wish mypkg@D:/dev/mypkg - mycmd`

### Launcher Script Guide
The Wish launcher (Launcher) is essentially a GUI tool started via the wish command, e.g., `wish launcher - launcher`
- Launcher depends on PySide2 (for GUI), and can be auto-updated via the server
- On Windows, use wish.cmd to launch
- On Linux, use the wish script to launch
- The launcher itself is not a standalone executable, but an extension module of wish
- Users can package the launcher script as an executable (e.g., exe)
- You can configure the startup script by modifying environment variables

## Launcher Guide
The default launcher provides user management, project management, launcher config management, and a built-in wish environment. Users can integrate their own workflows; the default launcher is for demo/reference.

### User Management
Create/delete users, assign roles/permissions
### Project Management
Add/delete projects and tasks, assign users to projects/tasks
### Launcher Management
Create/update/delete/enable/disable launchers under projects/tasks; launchers are inherited by default, but can be disabled in sub-tasks

## Environment Variables
Wish provides cross-platform init scripts to auto-configure env vars and launch wish:
- Linux: [wish](./platforms/linux/wish), [launcher](./platforms/linux/launcher)
- Windows: [wish](./platforms/windows/wish.cmd), [launcher](./platforms/windows/launcher.ps1)

These scripts auto-set env vars and call the main program; users can modify or package as needed.

Main env vars:
- **WISH_LOCAL**: root dir
- **WISH_PYTHON**: Python version
- **WISH_VERSION**: Wish version
- **WISH_PACKAGE_PATH**: package storage
- **WISH_STORAGE_PATH**: cache dir
- **WISH_DEVELOP_PATH**: dev dir
- **WISH_PACKAGE_ROOT**: Python package root
- **LD_LIBRARY_PATH**: lib path (Unix)
- **PATH**: bin path
- **WISH_RESTAPI_URL**: REST API
- **WISH_STORAGE_URL**: storage service
- **WISH_PKGSYNC_MODE**: cache sync mode (0=default, 1=disable cache, 2=dev dir)

To customize, edit the init script or set system env vars.

## Dependencies
Wish and the launcher depend on these core components (already packaged):
- **wish**: package parsing
- **7zip**: compression
- **minio**: object storage
- **requests**: HTTP requests
No separate installation needed; download the right package for your platform.

## FAQ

Q: Is @path required?
A: No. If omitted, Wish uses the default cache path or remote source.

Q: Is the command required?
A: No. You can use Wish just to cache packages and dependencies.

Q: How to enable verbose mode?
A: Use + instead of -, e.g. wish requests +

Q: Launcher won't run or says permission denied?
A: Check script file permissions. On Windows, try "Run as administrator". On Linux, ensure execute permission (chmod +x).

Q: Environment variables not effective?
A: Set them directly in the startup script or in your system environment. Some variables require restarting the terminal or system.

Q: How to switch Wish's cache, package directory, etc.?
A: Set `WISH_LOCAL`, `WISH_STORAGE_PATH`, `WISH_PACKAGE_PATH`, or modify the startup script directly.

Q: Command not found after starting Wish?
A: Make sure the PATH environment variable includes the wish directories, or use the full path for wish commands.

Q: How to integrate Wish in automation scripts?
A: Use `wish.cmd` or `launcher.ps1`, which support passing arguments and environment variables, suitable for batch tasks and CI.

Q: What if there are dependency conflicts?
A: Wish prioritizes the package and version specified in the command. For conflicts, specify a clear version range or use ban() in package.py to exclude conflicting packages.

Q: How to clear the local cache?
A: Delete the caches directory. Wish will re-fetch and cache required packages on the next request.

Q: How to debug package.py?
A: Add print statements in package.py or use wish + for verbose output and script path info.

Q: How to customize Wish behavior?
A: Set environment variables (WISH_LOCAL, WISH_STORAGE_PATH, etc.) or modify package.py for advanced logic.

Q: How to run Wish on Windows?
A: Use windows/wish.cmd or windows/launcher.ps1, which support command line arguments and environment variables.

Q: How to run Wish on Linux?
A: Use linux/wish or linux/launcher, and ensure execute permission (chmod +x).

Q: What if a package or dependency is not loaded correctly?
A: Check the command format, package.py dependencies, environment variables, and use wish + for detailed logs.

Q: Which Python versions are supported?
A: By default, the Python version bundled in the resource package is used. You can set WISH_PYTHON, but it's not recommended.

Q: How to contribute your own package?
A: Follow the package structure (with package.py), submit to the package repo or local develop directory, and debug with wish @path.

Q: How is the backend deployed and what tech stack is used?
A: The backend currently uses Gitlab and its runner service for packaging and CICD, uploads data to minio object storage, and updates relationships to a neo4j graph database. This allows querying upstream/downstream packages and supports automated testing and notification for downstream packages when upstream packages are pre-released.

## Contributing Guide
Fork this project;

Create a feature branch;

Submit a PR with a description;

Follow a concise and consistent documentation style;
