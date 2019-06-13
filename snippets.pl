use strict;
use warnings;
use Text::ParseWords();

my @sel_content = Text::ParseWords::shellwords($ENV{"kak_selections"});

my %placeholder_id_to_default;
my @placeholder_ids;

for my $i (0 .. $#sel_content) {
    my $sel = $sel_content[$i];
    $sel =~ s/\A\$\{?|\}\Z//g;
    my ($placeholder_id, $placeholder_default) = ($sel =~ /^(\d+)(?::(.*))?$/);
    if ($placeholder_id eq "0") {
        $placeholder_id = "9999";
    }
    $placeholder_ids[$i] = $placeholder_id;
    if (defined($placeholder_default)) {
        $placeholder_id_to_default{$placeholder_id} = $placeholder_default;
    }
}

print("set-option window snippets_placeholder_info");
for my $placeholder_id (@placeholder_ids) {
    print(" $placeholder_id");
    if (exists $placeholder_id_to_default{$placeholder_id}) {
        print("|1");
    } else {
        print("|0");
    }
}
print("\n");

print("set-register dquote");
for my $placeholder_id (@placeholder_ids) {
    if (exists $placeholder_id_to_default{$placeholder_id}) {
        my $default = $placeholder_id_to_default{$placeholder_id};
        # de-double up closing braces
        $default =~ s/\}\}/}/g;
        # double up single-quotes
        $default =~ s/'/''/g;
        print(" '$default'");
    } else {
        print(" ''");
    }
}
print("\n");
