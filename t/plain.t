use lib qw( ./blib/lib/ );
use Test::Simple tests => 5;
use Parse::Plain;

ok($] >= 5.005, 'Perl version');

@SUBCLASS::ISA = qw( Parse::Plain );
$t1 = new Parse::Plain './t/tmpl/1.tmpl';
$t2 = new SUBCLASS './t/tmpl/2.tmpl';
ok(UNIVERSAL::isa($t2, 'Parse::Plain'), 'empty subclass');

$t2->set_tag('space', ' ');

$t1->set_tag('tag1', 'TAG1');
$t1->set_tag('tag2', $t2);
ok($t1->get_tag('tag2') eq 'Second template', 'object reference passed to set_tag()');

$t1->set_tag('DP', '%%');
$t1->set_tag('DCL', '{{');
$t1->set_tag('DCR', '}}');
ok($t1->get_tag('DP') eq '%%', 'get_tag(\'DP\')');

$t1->parse('bl7', {}, 1);
$t1->parse('bl6', {}, 1);
$t1->parse('bl5', {}, 1);
$t1->parse('bl7', {}, 1);
$t1->parse('bl4', {}, 1);
$t1->parse('bl4', {}, 1);
$t1->parse('bl3', {}, 1);
$t1->parse('bl2', {}, 1);
$t1->parse('bl1', {}, 1);
open(RESULT, '<./t/tmpl/result.12');
$result = join('', <RESULT>);
close(RESULT);
ok($result eq $t1->parse(), 'final result');