# k3sinstallation
Script to run k3s with metallb and NFS mount

Prerequisites:
* OS: Ubuntu 20.04 (Havent test another version av Ubuntu right now)
* SSH-Key on your workers that allow root to access as a user from master.
* Allow your user to run commando with NOPASSWD on workers
* NFS share that master and workers can access.
