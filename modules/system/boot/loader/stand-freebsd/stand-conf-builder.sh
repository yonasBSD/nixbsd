#! @bash@/bin/sh -e

export PATH=/empty
for i in @path@; do PATH=$PATH:$i/bin; done

usage() {
    echo "usage: $0 -t <timeout> -c <path-to-default-configuration> [-d <boot-dir>] [-g <num-generations>]" >&2
    exit 1
}

timeout=                # Timeout in centiseconds
default=                # Default configuration
target=/boot            # Target directory
numGenerations=0        # Number of other generations to include in the menu

while getopts "t:c:d:g:n:r" opt; do
    case "$opt" in
        t) # U-Boot interprets '0' as infinite and negative as instant boot
            if [ "$OPTARG" -lt 0 ]; then
                timeout=0
            elif [ "$OPTARG" = 0 ]; then
                timeout=-10
            else
                timeout=$((OPTARG * 10))
            fi
            ;;
        c) default="$OPTARG" ;;
        d) target="$OPTARG" ;;
        g) numGenerations="$OPTARG" ;;
        \?) usage ;;
    esac
done

[ "$timeout" = "" -o "$default" = "" ] && usage

# Convert a path to a file in the Nix store such as
# /nix/store/<hash>-<name>/file to <hash>-<name>
cleanName() {
    local path="$1"
    echo "$path" | sed -r 's|^/nix/store/([^/]+).*$|\1|'
}

# Copy a file from the Nix store to $target/nixos.
declare -A filesCopied

addEntry() {
    local path="$1"  # boot.json
    local tag="$2"  # Generation number or 'default'

    local kernelPath=$(jq -r '."org.nixos.bootspec.v1".kernel' <$path)
    local rootDevice=$(jq -r '."gay.mildlyfunctional.nixbsd.v1".rootDevice' <$path)

    modulePath=$rootDevice:$(dirname $kernelPath)
    kernelName=$(basename $kernelPath)

    cat <<EOF
M.entries["$tag"] = {
	kernel = "$modulePath",
	label = $(jq -r '."org.nixos.bootspec.v1".label | @json' <$path),
	toplevel = $(jq -r '."org.nixos.bootspec.v1".toplevel | @json' <$path),
	init = $(jq -r '."org.nixos.bootspec.v1".init | @json' <$path),
        kernelEnvironment = {["init_script"] = $(jq -r '."org.nixos.bootspec.v1".toplevel + "/activate" | @json' <$path), $(jq -r '."gay.mildlyfunctional.nixbsd.v1".kernelEnvironment | to_entries | map("[\(.key | @json)] = \(.value | @json)") | join(", ")' <$path)},
        earlyModules = $(jq -r '."gay.mildlyfunctional.nixbsd.v1".earlyModules | @json' <$path | tr [] {}),
}
M.tags[#M.tags + 1] = "$tag"
EOF
}

tmpFile="$target/stand.lua.tmp.$$"

cat > $tmpFile <<EOF
-- Generated file, all changes will be lost on nixbsd-rebuild!

-- Change this to e.g. nixbsd-42 to temporarily boot to an older configuration.
M = {}
M.default = "nixbsd-default"
M.timeout = $timeout
M.entries = {}
M.tags = {}

EOF

addEntry $default/boot.json default >> $tmpFile

if [ "$numGenerations" -gt 0 ]; then
    for generation in $(
            (cd /nix/var/nix/profiles && ls -d system-*-link/boot.json 2>/dev/null) \
            | sed 's#system-\([0-9]\+\)-link/boot.json#\1#' \
            | sort -n -r \
            | head -n $numGenerations); do
        link=/nix/var/nix/profiles/system-$generation-link/boot.json
        addEntry $link $generation
    done >> $tmpFile
    for profile in $(cd /nix/var/nix/profiles/system-profiles && ls -d * 2>/dev/null | grep -v -- '-link$'); do
        for generation in $(
                (cd /nix/var/nix/profiles/system-profiles && ls -d $profile-*-link/boot.json 2>/dev/null) \
                | sed 's#.*-\([0-9]\+\)-link/boot.json#\1#' \
                | sort -n -r \
                | head -n $numGenerations); do
            link=/nix/var/nix/profiles/system-profiles/${profile}-${generation}-link/boot.json
            addEntry $link ${profile}-${generation}
        done
    done >> $tmpFile
fi

echo "return M" >> $tmpFile

targetBoot=$target/boot
mkdir -p $targetBoot
rm -rf $targetBoot/{lua,defaults}
cp -r @stand@/bin/{lua,defaults} $targetBoot
chmod +w $targetBoot/lua
mv $targetBoot/lua/loader.lua $targetBoot/lua/loader_orig.lua
cp @loader_script@ $targetBoot/lua/loader.lua
mv $tmpFile $targetBoot/lua/stand_config.lua
mkdir -p $targetBoot/loader.conf.d

if [ -n "@initmd@" ]; then
cp "@initmd@" "$targetBoot/initmd"
fi

mkdir -p $target/efi/boot
cp @stand@/bin/loader.efi $target/efi/boot/bootx64.efi

for fn in $(ls -d $target/nixos/* 2>/dev/null); do
    if ! test "${filesCopied[$fn]}" = 1; then
        echo "Removing no longer needed boot file: $fn"
        chmod +w -- "$fn"
        rm -rf -- "$fn"
    fi
done
