# complete rewrite (Feb 2019)

This is a complete rewrite of the code, to accommodate the fact that the old
code no longer works under git v2.18 and above, due to fundamental changes in
how git runs upload-pack.  Basically, I am unable to fool it into executing
gitpod's wrapper instead of the real "git-upload-pack", something that is
required for the old version to do its thing.  Luckily, I realised that
git-daemon has (and apparently always had!), an "access hook" option, which
gives us an "in".

# hardcoded stuff (customisation TBD!) and other backward incompatibilities

The script currently has some hardcodings; please let me know if you need any
of them made more flexible/customisable

-   hardcoded to github.com
-   hardcoded "lazy" duration (just under 2.5 hours)

Also, there is also no support for ssh mode now; if authenticated access to
cached repos is needed, it's best done using gitolite, and enabling the
"upstream" trigger.

# install and use

-   best to create a special userid only for this

-   put this program in $HOME/bin in that userid
    ```
    git clone --depth=1 https://github.com/azhai/gitpod
    mkdir $HOME/bin $HOME/pods
    cp gitpod/gitpod $HOME/bin/
    chmod +x $HOME/bin/gitpod
    ```

-   run this command
    ```
    git daemon --access-hook=$HOME/bin/gitpod --base-path=$HOME/pods  \
        --informative-errors --max-connections=2                     \
        --export-all --reuseaddr --verbose --detach
    ```

    The "max-connections" is optional; I am running this on a very low-RAM
    box, so it helps me.  (Sadly, git-daemon produces a cryptic "Connection
    reset by peer" when the limit is exceeded; be sure to inform your users
    that if they see that message they should try again after some time!)

-   add repos using this command (change the GITHUB_USER/GITHUB_REPO to yourself):

    ```
    $HOME/bin/gitpod add GITHUB_USER/GITHUB_REPO
    ```

-   (OPTIONAL) add the "status" repo
    ```
    cd $HOME/pods
    git init status
    cd status
    git commit --allow-empty -m empty
    ```

# for "users"

Users use this as `git://this.host.ip/GITHUB_USER/GITHUB_REPO` (for example `git
clone git://127.0.0.1/azhai/gitpod`)

# finding the status

There's a very kludgey method to check what repos have recently been "fetched"
from github.com: just run an ls-remote on a repo called "status":
    ```
    git ls-remote git://this.host.ip/status
    ```

A list of tags will show up, each of which is a carefully formatted set of
date, time, IP address, and repo name.

Yes, it's a kludge, as I already said, but if you can think of a better way to
show users *something*, I'd be happy to hear it.
