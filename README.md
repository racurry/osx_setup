# Setup a new OS X machine

## Set up a new machine

Or just update a current one.  These scripts should be idempotent.

### Step 0: Clone this repo

1. Generate a new ssh key:
`ssh-keygen -t rsa`
2. Copy it to your clipboard:
`pbcopy < ~/.ssh/id_rsa.pub`
3. Add it here: [github settings](https://github.com/settings/keys)
4. Clone the repo:
`mkdir ~/workspace`
`git clone git@github.com:racurry/osx_setup.git ~/workspace`

### Step 1: Run the setup

```
cd osx_setup
./setup.rb
```

## Adding new stuff

Dump it into the relevant `txt` file in `data`.

## References

### macOS settings
- http://www.bresink.com/osx/TinkerTool.html

### Cask lists
- https://formulae.brew.sh/
