package Parse::Plain;

require 5.005;
use strict;


BEGIN
{
	use Exporter;
	use Carp;
	use Data::Dumper;
	use vars  qw( $VERSION $loop_cnt_max $sleep_sec );

	$VERSION = "2.02";

	$loop_cnt_max = 5; # Number of attempts to open file
	$sleep_sec    = 1; # Number of seconds to sleep if file can't be opened
}


# Constructor
sub new
{
	my $type = shift;
	my ($template) = @_; # template file name is mandatory parameter
	my ($loop_cnt, @lines, $line, $block, $block_open, $s_block, @bl_stack, @bl_name_stack);
	my $self = {};

	$self->{'text'}   = ''; # result
	$self->{'hparse'} = {}; # hash of tags - values
	$self->{'hblock'} = {}; # hash of blocks
	$self->{'parsed'} = 0;

	unless (-f $template) {
		&_my_error("template not found: $template");
	}

	unless (-r $template) {
		&_my_error("template not readable: $template");
	}

	while (1) {
		if (open(TMPL, '<' . $template)) {
			@lines = <TMPL>;
			close(TMPL);
			last;
		} elsif ($loop_cnt > $loop_cnt_max) {
			&_my_error('loop counter exceeded while trying to read template ' .
			           "$template ($loop_cnt_max)");
		} else {
			sleep $sleep_sec;
			$loop_cnt++;
		}
	}

	$block = \$self->{'text'};
	$block_open = '';
	foreach $line(@lines) {
		if ($line =~ m/^\s*{{\s*([\!\w\d\.-_]+)$/) {
			push @bl_name_stack, $block_open
				if ($block_open);

			if (substr($1, 0, 1) eq '!') {
				$s_block = 1;
				$block_open = substr($1, 1);
			} else {
				$s_block = 0;
				$block_open = $1;
			}

			chomp $$block
				if ($$block);
			$$block .= ('%%!' . $block_open . '%%')
			    unless ($s_block);
			push @bl_stack, $block;
			$block = \$self->{'hblock'}->{$block_open};
			next;
		}
		if (($line =~ m/^\s*}}/) && $block_open) {
			chomp $$block
				if ($$block);
			$block = pop @bl_stack;
			$block_open = pop @bl_name_stack;
			next;
		}
		$$block .= $line;
	}
	
	if ($block_open) {
		&_my_error("in $template: block not closed");
	}
	
	return bless $self, $type;
}


# Set tag in %hparse
sub set_tag
{
	my ($self, $tag, $val) = @_;

	unless ($tag) {
		&_my_error('required parameter missing ($tag)');
	}

	if (UNIVERSAL::isa($val, 'Parse::Plain')) {
		$self->{'hparse'}->{$tag} = $val->parse;
	} else {
		$self->{'hparse'}->{$tag} = $val;
	}
}


# Retrieve tag from %hparse
sub get_tag
{
	my ($self, $tag) = @_;

	unless ($tag) {
		&_my_error('required parameter missed ($tag)');
	}

	return $self->{'hparse'}->{$tag};
}


# Appends $val to tag
# Returns: new value of tag
sub push_tag
{
	my ($self, $tag, $val) = @_;

	unless ($tag) {
		&_my_error('required parameter missing ($tag)');
	}
	
	if (UNIVERSAL::isa($val, 'Parse::Plain')) {
		$self->{'hparse'}->{$tag} .= $val->parse;
	} else {
		$self->{'hparse'}->{$tag} .= $val;
	}

	return $self->{'hparse'}->{$tag};
}


# Appends tag to $val and stores result in tag
# Returns new value of tag
sub unshift_tag
{
	my ($self, $tag, $val) = @_;

	unless ($tag) {
		&_my_error('required parameter missing ($tag)');
	}

	if (UNIVERSAL::isa($val, 'Parse::Plain')) {
		$self->{'hparse'}->{$tag} = $val->parse . $self->{'hparse'}->{$tag};
	} else {
		$self->{'hparse'}->{$tag} .= $val . $self->{'hparse'}->{$tag};
	}
	
	return $self->{'hparse'}->{$tag};
}


# block accessor
sub block
{
	my ($self, $block, $val) = @_;

	unless ($block) {
		&_my_error('required parameter missed (block)');
	}

	if ($val) {
		if (UNIVERSAL::isa($val, 'Parse::Plain')) {
			$self->{'block'}->{$block} = $val->parse;
		} else {
			$self->{'block'}->{$block} = $val;
		}
	}

	return $self->{'block'}->{$block};
}


# appends $val to 'block'
sub push_block
{
	my ($self, $block, $val) = @_;

	unless ($block) {
		&_my_error('required parameter missed (block)');
	}

	if (UNIVERSAL::isa($val, 'Parse::Plain')) {
		$self->{'block'}->{$block} .= $val->parse;
	} else {
		$self->{'block'}->{$block} .= $val;
	}

	return $self->{'block'}->{$block};
}


# Appends to $val value of 'block' and stores result in 'block'
# Returns new value of 'block'
sub unshift_block
{
	my ($self, $block, $val) = @_;

	unless ($block) {
		&_my_error('required parameter missed (block)');
	}

	if (UNIVERSAL::isa($val, 'Parse::Plain')) {
		$self->{'block'}->{$block} = $val->parse . $self->{'block'}->{$block};
	} else {
		$self->{'block'}->{$block} = $val . $self->{'block'}->{$block};
	}

	return $self->{'block'}->{$block};
}


# 'text' accessor. You should probably never use this.
sub set_text
{
	my ($self, $val) = @_;

	if (UNIVERSAL::isa($val, 'Parse::Plain')) {
		$self->{'text'} = $val->parse;
	} else {
		$self->{'text'} = $val;
	}

	return $self->{'text'};
}


# Returns 'text'
sub get_text
{
	my $self = shift;

	return $self->{'text'};
}


# Parse template or block. Returns parsing results.
# If $block param is specified block is parsed and $hparse{$block} is appended with result
# If also $href hash reference is specified the block is parsed using $href
# If also $usehparse is TRUE, then block will be parsed using 'hparse' hash also.
# Returns parsing results
sub parse
{
	my ($self, $block, $href, $usehparse) = @_;
	my ($res, $W);
	
	if (!$href) {
		$href = $self->{'hparse'};
	} elsif ($usehparse) {
		foreach (keys %{$self->{'hparse'}}) {
			$href->{$_} = $self->{'hparse'}->{$_}
				unless ($href->{$_});
		}
	}

	$W = $^W;
	$^W = 0;
	if ($block) {
		$res = $self->{'hblock'}->{$block};
		$res =~ s/%{2}([\w\d\.\:,\(\)\*\&\^\$;_-]+)%{2}/$href->{$1}/g;
		$res =~ s/%{2}(\![\w\d\.\:,\(\)\*\&\^\$;_-]+)%{2}/$self->{'hparse'}->{$1}/g;
		$self->{'hparse'}->{'!' . $block} .= $res;
	} else {
		if ($self->{'parsed'}) {
			$^W = $W;
			return $self->{'text'};
		}
		$self->{'text'} =~ s/%{2}([\w\d\.\:,\(\)\*\&\^\$;_-]+)%{2}/$href->{$1}/g;
		$self->{'text'} =~ s/%{2}(\![\w\d\.\:,\(\)\*\&\^\$;_-]+)%{2}/$self->{'hparse'}->{$1}/g;
		$res = $self->{'text'};
		$self->{'parsed'} = 1;
	}
	$^W = $W;
		    
	return $res;
}


# Print parsing results. If template already parsed prints it
# otherwise parse template first.
sub output
{
	my $self = shift;

	print $self->parse;

	return $self->{'text'};
}


# Die with specified message.
sub _my_error
{
	my $msg = shift;
	my @caller;

	@caller = caller(0);

	croak "$caller[1] [$caller[2]]: in subroutine $caller[3]: $msg";

	return;
}


1;


__END__


=head1 NAME

 Parse::Plain - simple template parsing engine

=head1 SYNOPSIS

 # in user's code
 use Parse::Plain;

 my $t = new Parse::Plain('filename.tmpl');

 $t->set_tag('mytag', 'value');          # %%mytag%% set to value
 $t->push_tag('mytag', '-pushed');       # %%mytag%% set to value-pushed
 $t->set_tag('mytag', 'value');          # %%mytag%% set to value
 $t->unshift_tag('mytag', 'unshifted-'); # %%mytag%% set to unshifted-value

 $t->push_block('myblock', 'some text to append to the block');
 $t->unshift_block('myblock', 'some text to prepend to the block');

 $t->parse('myblock', {'blocktag' => 'block value'});  # parse block
 $t->parse('myblock', {'blocktag' => 'another block value'});

 $t->parse;   # parse whole document
 $t->output;  # output parsed results to STDOUT


=head1 DESCRIPTION

Parse::Plain is a simple module for parsing text templates. It was
designed to use on HTML, XHTML, XML and other markup languages
but usually can also be used on arbitrary text files.

Basic constructions in the templates are tags and blocks. Both 
have names. Valid symbols for using in tag and block names are digits,
latin letters, underscores, dashes, dots, semicolons, colons, commas,
parentheses, asterisks, ampersands and caret symbols. An exclamation 
mark ('B<!>') has special meaning and will be discussed later. All names 
are case sensitive.

Tag is a string in form B<%%tagname%%>. There may be any number of tags 
with the same name in the template and any number of different tags.

Block is a construction that begins with line

B<{{ blockname>

and ends with line

B<}}>

Both block-start and block-end elements must be on separate lines.
Symbols between block-start and block-end form block body. Blocks are
especially useful for iterative elements like table rows etc. Blocks
can be nested and tags are allowed within block body.

There also is a special form of tag names. Lets say you have a block
named myblock. Then you can use in your template tags named B<%%!myblock%%>
and they will be substituted to current value of myblock.

You can also hide block from place in template where it is defined
by prepending B<!> to it's name. Then you'll only be able to show this 
block using appropriate tag names (with 'B<!>'). See L<EXAMPLES> section.


=head1 METHODS

=head2 new()

The constructor. The only parameter is a path to template file.
Template file must exist and be readable. If file cannot be read
several attempts will be made (see I<$loop_cnt_max> and I<$sleep_sec>
variables at the BEGIN section).

=head2 set_tag()

Tags accessor. Requires parameters: tagname, value. Example:

B<$t-E<gt>set_tag('mytag', 'value'); # set %%mytag%% to 'value'>

Value may be another instance of Parse::Plain. In this case parse method
will be called automatically on value object.
Returns new value of tag.

=head2 get_tag()

Tags accessor. Requires one parameter: tagname. Returns current
value of tag.

=head2 push_tag()

Append supplied value to current value of tag. Requires parameters:
tag name and value. Value may be an instance of Parse::Plain. In this case 
parse method will be called automatically on value object.
Returns new value of tag.

=head2 unshift_tag()

Prepend supplied value to current value of tag. Requires parameters: 
tag name and value. Value may be an instance of Parse::Plain. In this case 
parse method will be called automatically on value object.
Returns new value of tag.

=head2 block()

Block accessor. Requires parameter: block name. Second parameter 
(value) is optional. If it is omitted current value of block is 
returned, otherwise it's set to a new value. Value may be an instance 
of Parse::Plain. In this case parse method will be called automatically on 
value object.
Returns new value of the block or old value if the block wasn't changed.

=head2 push_block()

Append supplied value to block. Required parameters: block name, value.
Value may be an instance of Parse::Plain. In this case parse method will be 
called automatically on value object.
Returns new value of the block.

=head2 unshift_block()

Prepend supplied value to block. Required parameters: block name, value.
Value may be an instance of Parse::Plain. In this case parse method will be 
called automatically on value object.
Returns new value of the block.

=head2 set_text()

Set text to parameter. Text is a special member containing outermost
block source if hasn't been parsed yet or whole parsed results if 
L<parse()> method has already been called.
B<WARNING:> You should probably never use this function directly!
Return new value of text.

=head2 set_text()

Returns current value of text. Text is a special member containing 
outermost block source if hasn't been parsed yet or whole parsed results 
if L<parse()> method has already been called.
B<WARNING:> You should probably never use this function directly! See
parse() function elsewhere is this document!

=head2 parse()

Parse chunk of text using defined tags and blocks.
If called without parameters the template is parsed using tags and
blocks defined so far.
There are three optional parameters: I<blockname>, I<hashref>, 
I<useglobalhash>. First specifies block name to be parsed. You must call
L<parse()> function on each block in your template at least onse or the
block will be ignored. You must also call L<parse()> function for each 
iteration of the block. See L<EXAMPLES> section elsewhere in this document.
You can also provide a referense to hash of tags used for parsing
current block. For example:

B<$t-E<gt>parse('blockname', {'tag1' =E<gt> 'val1', 'tag2' =E<gt> 'val2'});>

If you don't specify this hash reference global hash (filled with
L<set_tag()> functions) wiil be used instead.
You can also use both supplied hash and global hash for parsing your
block by setting third parameter to true. 
Returns parsing results (either text or block).

=head2 output()

Print parsing results to STDOUT. If text hasn't been parsed yet calls
L<parse()> method before.
Returns parsed text.


=head1 TIPS AND CAVEATS

=item *
Names are case sensitive.

=item *
Non-defined tags and blocks are moved off from the result

=item *
Block start and end elements do not insert newline. Consider the
template fragment:

       He
  {{ myblock
ll
  }}
o

It will be parsed to

B<      Hello>

line.

=item *
Block start and end elements may be padded with whitespaces or tabs 
for better readability.

=item *
Always parse innermost block before outer blocks.

=item *
Blocks may be reparsed with different values, tags also can be reset.


=head1 EXAMPLES

=head2 Using blocks

B<Template (template.tmpl):>
 <table>
 <th>%%name%%</th>

 {{ block1
         <tr><td>%%tag1%%</td><td>%%tag2%%</td></tr>

 }}
 </table> 

B<Code:>
 use Parse::Plain;
 $t = new Parse::Plain 'template.tmpl';
 $t->set_tag('name', "My table");
 $t->parse('block1', {'tag1' => '01', 'tag2' => '02'});
 $t->parse('block1', {'tag1' => '03', 'tag2' => '04'}); 
 $t->output;

B<Output:>
 <table>
 <th>My table</th>
         <tr><td>01</td><td>02</td></tr>
         <tr><td>03</td><td>04</td></tr>
 </table>

=head2 Using hidden blocks

B<Template (template.tmpl):>
 <table %%border%%>

 {{ myblock
         <tr><td %%!hidden%%>%%value%%</td></tr>

 }}
 </table>

 {{ !hidden
 class="%%class%%" align="%%align%%"
 }}

B<Code:>
 use Parse::Plain;
 $t = new Parse::Plain 'template.tmpl';
 $t->parse('hidden', {'class' => 'red', 'align' => 'right'});
 $t->parse('myblock', {'value' => '01'});
 $t->parse('myblock', {'value' => '02'}); 
 # we didn't define %%border%% tag
 $t->output;

B<Output:>
 <table >
         <tr><td  class="red" align="right">01</td></tr>
         <tr><td  class="red" align="right">02</td></tr>
 </table>


=head1 BUGS

If you define a hidden block (with 'B<!>') and a nested block inside it
and use tag to show the hidden block (outer) behavior is undefined.

You have no way to change tag / block delimiters. See FAQ document
provided with distribution for more details.

If you have found any other bugs or have any comments/wishes don't
hesitate to contact me.


=head1 AUTHOR

 Andrew Alexandre Novikov.
 mailto: perl@an.kiev.ua
 www: http://www.an.kiev.ua/
 icq: 7593332


=head1 COPYRIGHTS

Copyright 2003 by Andrew A Novikov <http://www.an.kiev.ua/>.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

See http://www.perl.com/perl/misc/Artistic.html

