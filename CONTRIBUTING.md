# Contributing to MultiPlay Core Project

## Contributing to the Source Code

### Readability 
The way commit messages are written is important too, so that we know and understand what the commit is about. It should be written in English. Example like:
- Add a button that creates a game
- Added Support for Platform
- [Fix] Player spawns spam bug
- MPTransformSync: Added Lerp

(For full class names, they can be shortened into their abbreviations, such as MultiPlayCore -> MPC, MPPlayer -> MPP, MPTransformSync -> TransformSync)

### About Big Pull Requests
If possible, please split big commits into separate pull requests. This makes reviewing much easier. If codes were dependent on each other, you can cherry-pick the commit first.

## Reporting Issues

### Filling out issues
If you encounter a bug while using the library, you can fill out the issues [here](https://github.com/maji-git/multiplay-core/issues).

## Contributing to Documentation

### APIs Documentation
You can annotate API documentation with GDScript's annotation. Check [this out](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html) for more info on how to use them.

Generating pages for API documentation is usually done after each version. The guide will be addressed later

### Documentation Page
The documentation runs in hugo. If you want to run the page, you'll need to [install hugo](https://gohugo.io/installation/) first. Docs content uses markdown, HTML content is not supported. However, you can use shortcodes.

Documentation Repository lives [here](https://github.com/maji-git/mpc-docs/)

## Deployment, how's it done?

### Deploy at Godot AssetLib
When a new version is released. The repository owner (maji) will update the commit hash at the Godot Asset Library system. To make sure the new download gets the latest version.

### Deploy at mpc-deploy
Deployment is also done at [mpc-deploy](https://github.com/maji-git/mpc-deploy). The purpose is for faster deployment because Godot AssetLib moderation does take time, and can be slow for hot fixes, etc. This is used in MPC's built-in update checker.

When a new version is released, `release-info.json` will update, pointing the commit hash/download URL to that new version's commit.

## Discussing with other Contributors

Contributors can discuss in [hi maji! Discord Server](https://discord.gg/cu6y53kJQn) It's where discussion about MultiPlay Core usually happens.
