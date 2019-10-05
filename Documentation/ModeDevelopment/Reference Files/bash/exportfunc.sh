# normal operation
foo()
{
	echo exportfunc ok 1
}
export -f foo
${THIS_SH} -c foo
unset -f foo
foo-a ()
{
	echo exportfunc ok 2
}
export -f foo-a
${THIS_SH} -c 'foo-a'

# CVE-2014-6271

env -i BASH_FUNC_foo%%='() { echo cve6271 ok; } ; echo BAD' ${THIS_SH} -c foo 2>/dev/null

# CVE-2014-7169

rm -f cve7169-bad
env -i BASH_FUNC_X%%='() { (a)=>\' ${THIS_SH} -c cve7169-bad 2>/dev/null
: < cve7169-bad
rm -f cve7169-bad

echo cve7169-bad2 > $TMPDIR/bar
rm -f cve7169-bad2
eval  'X() { (a)>\' ; . ./bar 2>/dev/null
: < cve7169-bad2
rm -f cve7169-bad2 $TMPDIR/bar

# CVE-2014-7186
${THIS_SH} ./exportfunc1.sub

# CVE-2014-7187
${THIS_SH} ./exportfunc2.sub

# CVE-2014-6277

env BASH_FUNC_foo%%="() { 000(){>0;}&000(){ 0;}<<0 0" ${THIS_SH} -c foo 2>/dev/null
env BASH_FUNC_foo%%="() { 000(){>0;}&000(){ 0;}<<`perl -e '{print "A"x100000}'` 0" ${THIS_SH} -c foo 2>/dev/null
${THIS_SH} -c "f(){ x(){ _;}; x(){ _;}<<a;}" 2>/dev/null

# CVE-2014-6278

env 'BASH_FUNC_FOO%%=() { 0;}>r[0${$(}0 {>"$(id >/dev/tty)"; }' ${THIS_SH} -c : 2>/dev/null

rm -f HELLO_WORLD
env BASH_FUNC_FOO%%='() { 0;}>r[0${$(}0 {>HELLO_WORLD; }' ${THIS_SH} -c : 2>/dev/null
: < HELLO_WORLD

env BASH_FUNC_x%%='() { _;}>_[$($())] { echo vuln;}' ${THIS_SH} -c : 2>/dev/null

env -i BASH_FUNC_x%%='() { _; } >_[${ $() }] { id; }' ${THIS_SH} -c : 2>/dev/null

env BASH_FUNC_x%%=$'() { _;}>_[$($())]\n{ echo vuln;}' ${THIS_SH} -c : 2>/dev/null
eval 'x() { _;}>_[$($())] { echo vuln;}' 2>/dev/null

eval 'foo() { _; } >_[${ $() }] ;{ echo eval ok; }'

# other tests fixed in bash43-030 concerning function name transformation
env $'BASH_FUNC_\nfoo%%=() { echo transform-1; }' ${THIS_SH} -c foo 2>/dev/null
env $'BASH_FUNC_foo\n%%=() { echo transform-2; }' ${THIS_SH} -c foo 2>/dev/null
env $'BASH_FUNC_  foo  %%=() { echo transform-3; }' ${THIS_SH} -c foo 2>/dev/null

unset -f foo
env $'BASH_FUNC_#badname%%'=$'() { :; }\nfoo () { echo transform-4; }  ' ${THIS_SH} -c 'foo' 2>/dev/null

# tests of exported names
${THIS_SH} ./exportfunc3.sub
