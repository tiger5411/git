/**
 * @author Arnar Mar Sig <antab@antab.is>
 * @addtogroup addon_printf
 * @{
 */

#include <kernel.h>
#include <string.h>
#include <addon/printf.h>

/**
 * Helper function do output number prefixes
 * @param flags			Format flags
 * @param radix			Number base
 * @param putc			Callback to do outputting
 * @param arg1			Pointer to argument 1, unused
 * @param arg2			Pointer to argument 2, unused
 * @return				Number of characters in prefix
 */
static int printf_number_prefix(int flags, int radix, printf_putc putc, void **arg1, void **arg2);

/**
 * Helper function for snprintf
 * @param c				Character to output
 * @param arg1			Pointer to destination buffer
 * @param arg2			Pointer to max buffer size
 */
static void snprintf_helper(char c, void **arg1, void **arg2);

int printf(const char *format, ...) {
	va_list args;
	int ret;

	va_start(args, format);
	ret = vprintf(format, args);
	va_end(args);

	return ret;
}

int vprintf(const char *format, va_list ap) {
	return printf_internal(format, ap, putc, NULL, NULL);
}

int snprintf(char *buffer, size_t size, const char *format, ...) {
	va_list args;
	int ret;

	va_start(args, format);
	ret = vsnprintf(buffer, size, format, args);
	va_end(args);

	return ret;
}

int vsnprintf(char *buffer, size_t size, const char *format, va_list ap) {
	int ret, helper_size;

	helper_size = size;
	ret = printf_internal(format, ap, snprintf_helper, (void *)buffer, (void *)&helper_size);
	if (ret > size) {
		buffer[size - 1] = '\0';
	}
	else {
		buffer[ret] = '\0';
	}
	return ret;
}

int printf_internal(const char *format, va_list ap, printf_putc callback, void *arg1, void *arg2) {
	int count, state, flags, width, actual_width, radix, *pos, int_size;
	char *string, buf[PRINTF_BUFLEN];
	intmax_t number;
	uintmax_t tmp;

	count = state = flags = int_size = 0;
	for (; *format; format++) {
		switch (state) {
			case 0:		// Normal chars
				if (*format != '%') {
					count++;
					callback(*format, &arg1, &arg2);
					continue;
				}
				flags = 0;
				int_size = PRINTF_SIZE_INT;
				state++;
				format++;
				// Fallthru
			case 1:		// Flag
				switch (*format) {
					case '%':
						count++;
						callback(*format, &arg1, &arg2);
						state = 0;
						continue;

					case '-':
						flags |= PRINTF_LEFT_ALIGN;
						continue;

					case '0':
						flags |= PRINTF_ZERO_PAD;
						continue;

					case '+':
						flags |= PRINTF_SHOW_SIGN;
						continue;

					case ' ':
						flags |= PRINTF_PAD_SIGN;
						continue;

					case '#':
						flags |= PRINTF_ALTERNATE;
						continue;
				}
				width = 0;
				state++;
				// Fallthru
			case 2:		// Field width
				if (*format >= '0' && *format <= '9') {
					width = 10 * width + (*format - '0');
					break;
				}
				// Fallthru
			case 3:		// Modifier chars
				switch (*format) {
					case 'l':
						if (int_size == PRINTF_SIZE_LONG) {
							int_size = PRINTF_SIZE_LONG_LONG;
						}
						else {
							int_size = PRINTF_SIZE_LONG;
						}
						continue;

					case 'h':
						if (int_size == PRINTF_SIZE_SHORT) {
							int_size = PRINTF_SIZE_CHAR;
						}
						else {
							int_size = PRINTF_SIZE_SHORT;
						}
						continue;

					case 'z':
						int_size = PRINTF_SIZE_SIZE_T;
						break;

					case 'j':
						int_size = PRINTF_SIZE_INTMAX_T;
						break;
				}
				state++;
				// Fallthru
			case 4:		// Conversion char
				switch (*format) {
					case 'p':
						flags |= PRINTF_ZERO_PAD | PRINTF_ALTERNATE;
						width = 10;
						radix = 16;
						goto do_num;

					case 'X':
						flags |= PRINTF_UPPERCASE;
					case 'x':
						flags &= ~(PRINTF_SHOW_SIGN | PRINTF_PAD_SIGN);
						radix = 16;
						goto do_num;

					case 'd':
					case 'i':
						flags |= PRINTF_SIGNED;
					case 'u':
						flags &= ~PRINTF_ALTERNATE;
						radix = 10;
						goto do_num;

					case 'o':
						flags &= ~(PRINTF_SHOW_SIGN | PRINTF_PAD_SIGN);
						radix = 8;
do_num:					switch (int_size) {
							case PRINTF_SIZE_LONG_LONG:
								number = va_arg(ap, unsigned long long);
								break;

							case PRINTF_SIZE_LONG:
								number = va_arg(ap, unsigned long);
								break;

							case PRINTF_SIZE_SIZE_T:
								number = va_arg(ap, size_t);
								break;

							case PRINTF_SIZE_INTMAX_T:
								number = va_arg(ap, intmax_t);
								break;

							default:
								// Other types are promoted to int
								number = va_arg(ap, unsigned int);
								break;
						}
						flags |= PRINTF_NUMBER;
						if (flags & PRINTF_SIGNED) {
							if (number < 0) {
								flags |= PRINTF_NEGATIVE;
								number = -number;
							}
						}
						string = buf + PRINTF_BUFLEN - 1;
						*string = '\0';
						do {
							string--;
							tmp = (uintmax_t)number % radix;
							if (tmp < 10) {
								*string = tmp + '0';
							}
							else {
								*string = tmp - 10 + ((flags & PRINTF_UPPERCASE)
									? 'A'
									: 'a');
							}
							number = (uintmax_t)number / radix;
						} while (number != 0);
						goto do_string;

					case 'c':
						string = buf;
						string[0] = (char)va_arg(ap, unsigned int);
						string[1] = '\0';
						goto do_string;

					case 's':
						string = va_arg(ap, char *);
do_string:				actual_width = strlen(string);
						if (flags & PRINTF_NUMBER) {
							if (flags & (PRINTF_NEGATIVE | PRINTF_SHOW_SIGN | PRINTF_PAD_SIGN)) {
								actual_width++;
							}
							else if (flags & PRINTF_ALTERNATE) {
								if (radix == 16) {
									actual_width += 2;
								}
								else if (radix == 8) {
									actual_width++;
								}
							}
						}
						// If pad with zero, then output sign now
						if (flags & PRINTF_ZERO_PAD) {
							count += printf_number_prefix(flags, radix, callback, &arg1, &arg2);
						}
						// Right align
						if ((flags & PRINTF_LEFT_ALIGN) == 0) {
							for (; width > actual_width; width--) {
								count++;
								callback(((flags & PRINTF_ZERO_PAD)
									? '0'
									: ' '), &arg1, &arg2);
							}
						}
						// If pad with space, then output sign now
						if ((flags & PRINTF_ZERO_PAD) == 0) {
							count += printf_number_prefix(flags, radix, callback, &arg1, &arg2);
						}
						while (*string != '\0') {
							count++;
							callback(*string++, &arg1, &arg2);
						}
						// Left align
						if (width > actual_width) {
							for (; width > actual_width; width--) {
								count++;
								callback(' ', &arg1, &arg2);
							}
						}
						state = 0;
						break;

					case 'n':
						printf("N\n");
						pos = va_arg(ap, int*);
				//		*pos = count;
						state = 0;
						break;

					default:
						break;
				}
				break;

			default:
				state = 0;
				break;
		}
	}
	return count;
}

static int printf_number_prefix(int flags, int radix, printf_putc callback, void **arg1, void **arg2) {
	if (flags & PRINTF_NUMBER) {
		if (flags & PRINTF_NEGATIVE) {
			callback('-', arg1, arg2);
			return 1;
		}
		if (flags & PRINTF_SHOW_SIGN) {
			callback('+', arg1, arg2);
			return 1;
		}
		if (flags & PRINTF_PAD_SIGN) {
			callback(' ', arg1, arg2);
			return 1;
		}
		if (flags & PRINTF_ALTERNATE) {
			if (radix == 16) {
				callback('0', arg1, arg2);
				callback(((flags & PRINTF_UPPERCASE)
					? 'X'
					: 'x'), arg1, arg2);
				return 2;
			}
			if (radix == 8) {
				callback('0', arg1, arg2);
				return 1;
			}
		}
	}
	return 0;
}

static void snprintf_helper(char c, void **arg1, void **arg2) {
	char *dst = *arg1;
	int *size = *arg2;

	if (*size == 1) {
		return;
	}
	*dst++ = c;
	(*size)--;
	*arg1 = dst;
}
//! @}
