#include "test-tool.h"
#include "git-compat-util.h"
#include "thread-utils.h"
#include "gettext.h"

int cmd__gettext_poison(int argc, const char **argv)
{
	return use_gettext_poison() ? 0 : 1;
}
