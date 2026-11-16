# Quality of life Bash scripts
This collection will initially consist of scripts I personally use but I hope it will grow and improve with input from others.

My scripts are and most likely will be written/rewritten with AI. I am not experienced with Bash and wanted to cover support for all shells and run optimally. 


## Scripts
#### Unified game directory symlinker
Keep your game launcher paths static with a single directory of your games consisting entirely of symlinks to your games. The script tracks specified directories across all drives, when a game is moved from one tracked dir to another, the symlink in the unified folder is updated to its new path. This way your launcher can still boot the game as if nothing was moved. 

#### Goverlay config space fix
Basic script that creates a symlink copy of a goverlay config with all spaces removed. This was to fix a launcher not properly parsing spaces in launch arguments.

