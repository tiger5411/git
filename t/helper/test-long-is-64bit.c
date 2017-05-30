#include "git-compat-util.h"

int cmd_main(int argc, const char **argv)
{
	return (8 <= (int)sizeof(long)) ? 0 : 1;
}
