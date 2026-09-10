# git tips

## git pull command

When you run `git pull`, Git fetches updates from your remote repository and needs to integrate them into your local branch.  
The fundamental difference between a **Fast-Forward** and a **Rebase** comes down to  
**whether your local branch has diverged from the remote branch**.

### Fast-Forward Only (Recommended)

A fast-forward is NOT an integration strategy;  
**it is a shortcut Git uses when no integration is needed.**  
It happens when you have no new local commits, meaning your local branch is just a few steps behind the remote repository.

+ How it works: Git does not combine code or create a "merge commit".  
  It simply moves (fast-forwards) your local branch pointer up to match the latest remote commit.
+ **During a git pull**: If you run `git pull --ff-only`,  
  Git will successfully update your branch if it can be fast-forwarded.  
  However, if you have made local commits, the pull will fail and throw an error because the histories have diverged

#### Config Fast-Forward

+ `git config --global pull.ff only`: Apply to all your repositories
+ `git config pull.ff only`: Apply to the current repository only
+ `git pull --ff-only`: Overriding the Config Temporarily

### Rebase

A rebase is an intentional integration strategy  
used when both you and the remote repository have new, different commits.

+ How it works: Git temporarily takes your unique local commits and lifts them out of the way.  
  It applies the new incoming remote commits first, and then replays your local commits one by one on top of them.
+ **During a git pull**: If you run `git pull --rebase`,  
  Git pulls the remote changes, puts them at the base of your branch, and stacks your local work cleanly on top.  
  This rewrites your local commit history so it looks like you started working after the remote changes were already made.

#### Config rebase

+ `git config --global pull.rebase true`: Global Configuration (All Repositories)
+ `git config pull.rebase true`: Local Configuration (Current Repository Only)
+ `git pull --rebase`: One-time override

## config user.name and Email

Check Current Settings:

+ View everything: `git config --list` (Shows all active configuration values)
+ View current username: `git config user.name`
+ View current email: `git config user.email`

### Set Globally (For all repositories)

+ Set Username: `git config --global user.name YourName`
+ Set Email: `git config --global user.email yourEmail@example.com`

### Set Locally (For a single repository)

+ Set Username: `git config user.name YourName`
+ Set Email: `git config user.email your.email@example.com`
