# AUTHORS
#
# The Veracruz Development Team.
#
# COPYRIGHT
#
# See the `LICENSE_MIT.markdown` file in the Veracruz root directory for licensing
# and copyright information.

set -e

if [ ! -f /nix/.installed ]; then
    echo "Installing Nix..."
    bash /work/install-nix.sh
    touch /nix/.installed
    chown -R $1 /nix
    chmod 0755 /nix
    echo "Done"
fi
