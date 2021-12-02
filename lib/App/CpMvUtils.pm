package App::CpMvUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use File::Basename;
use File::chdir;
use File::Find;
use File::Spec;
use Path::Naive; # XXX only supports unix style

# AUTHORITY
# DATE
# DIST
# VERSION

# TODO: do not fix relative symlink to location internal to tree, only links to
# external location.

sub _adjust_symlink {
    # both args must be symlinks, this is not checked again by this routine
    my ($symlink1, $symlink2) = @_;

    my $target1 = readlink $symlink1;
    if (!defined $target1) {
        log_warn "Cannot read source symlink %s, skipping adjusting", $symlink1;
        return;
    }
    my $target2 = readlink $symlink2;
    if (!defined $target2) {
        log_warn "Cannot read target symlink %s, skipping adjusting", $symlink2;
        return;
    }
    if (File::Spec->file_name_is_absolute($target1)) {
        log_trace "Skipping adjusting source symlink %s (target '%s' is absolute)", $symlink1, $target1;
        return;
    }
    if (File::Spec->file_name_is_absolute($target2)) {
        log_trace "Skipping adjusting target symlink %s (target '%s' is absolute)", $symlink2, $target2;
        return;
    }
    my $newtarget2 = Path::Naive::normalize_path(
        File::Spec->abs2rel(
            (File::Spec->rel2abs($target1, File::Basename::dirname($symlink1))),
            File::Spec->rel2abs(File::Basename::dirname($symlink2), "/"), # XXX "/" is unixism
        )
    );
    if ($target2 eq $newtarget2) {
        log_trace "Skipping adjusting target symlink %s (no change)", $symlink2, $newtarget2;
        return;
    }
    unlink $symlink2 or do {
        log_error "Cannot adjust target symlink %s (can't unlink: %s)", $symlink2, $!;
        return;
    };
    symlink($newtarget2, $symlink2) or do {
        log_error "Cannot adjust target symlink %s (can't symlink to '%s': %s)", $symlink2, $newtarget2, $!;
        return;
    };
    log_trace "Adjusted symlink %s (from target '%s' to target '%s')", $symlink2, $target2, $newtarget2;
}

sub _adjust_symlink_recursive {
    my ($dir1, $dir2) = @_;

    local $CWD = $dir1;
    find(
        sub {
            return if $_ eq '.';
            return unless -l $_;
            _adjust_symlink(
                File::Spec->catfile($dir1, $File::Find::dir, $_),
                File::Spec->catfile($dir2, $File::Find::dir, $_),
            );
        },
        ".",
    );
}

sub adjust_symlinks_in_target {
    my %args = @_;

    unless (defined $args{target} && @{ $args{sources} }) {
        log_info "No target/sources, skipping adjusting symlinks";
        return;
    }

    for my $source (@{ $args{sources} }) {
        if (-l $source) {
            if (-l $args{target}) {
                _adjust_symlink($source, $args{target});
            } elsif (-d _) {
                my ($vol, $dirs, $file) = File::Spec->splitpath($source);
                _adjust_symlink($source, File::Spec->catfile($args{target}, $file));
            } else {
                log_warn "Source (%s) is a symlink, but target (%s) is neither a ".
                    "directory or symlink, skipping", $source, $args{target};
            }
        } elsif (-d $source) {
            if (@{ $args{sources} } > 1 || $args{target_is_container}) {
                my ($vol, $dirs, $file) = File::Spec->splitpath($source);
                _adjust_symlink_recursive($source, File::Spec->catfile($args{target}, $file));
            } else {
                _adjust_symlink_recursive($source, File::Spec->catfile($args{target}));
            }
        }
    }
}

1;
# ABSTRACT: CLI utilities related to the Unix commands 'cp' and 'mv'

=for Pod::Coverage ^(.+)$

=head1 DESCRIPTION

This distribution includes the following CLI utilities related to the Unix
commands C<cp> and C<mv>:

# INSERT_EXECS_LIST

=cut
