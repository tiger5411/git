/**
 * Printf addon
 *
 * %[flags][width][.precision][length]type
 *
 * Flags:
 *	@li	number			Left pad output with space until required length is attained.
 *	@li	-				Left align output to required length instead of the default right-aligned.
 *	@li	+				Always output +/- for numeric types.
 *	@li [space]			For signed numbers, put space before a positive number.
 *	@li	0				Use 0 instead of space to left pad right aligned output.
 *	@li	#				Alternate form.
 *		@li o			Prepend 0
 *		@li x			Prepend 0x
 *		@li X			Prepend 0X
 *
 * Width:
 *	@li	number			Left pad output with space until required length is attained.
 *
 * Precision:
 *	TODO
 *
 * Length:
 *	@li	hh				Char integer (promoted to int)
 *	@li	h				Short integer (promoted to int)
 *	@li	l				Long integer
 *	@li	ll				Long long integer
 *	@li	z				size_t
 *	@li	j				intmax_t
 *
 * Type:
 *	@li %				Print %
 *	@li	d, i			Print integer as signed decimal number.
 *	@li	u				Print integer as unsigned decimal number.
 *	@li	x				Print integer as hexadecimal number using lowercase letters.
 *	@li	X				Print integer as hexadecimal number using uppercase letters.
 *	@li	o				Print integer as octal number.
 *	@li	p				Print pointer with 0x prepended.
 *	@li c				Print single character.
 *	@li s				Print character string.
 *	@li n				Print nothing but store the current output length in the argument.
 *
 * @defgroup addon_printf printf
 * @ingroup addon
 * @author Arnar Mar Sig <antab@antab.is>
 * @{
 */

#ifndef __ADDON_PRINTF_H__
#define __ADDON_PRINTF_H__

// Use GCC's buildin va arg implementation
typedef __builtin_va_list		va_list;
#define va_start(ap, last)		__builtin_stdarg_start((ap), (last))
#define va_end(ap)				__builtin_va_end((ap))
#define va_arg(ap, type)		__builtin_va_arg((ap), type)
#define va_copy(dst, src)		__builtin_va_copy((dst), (src))

// Misc flags used when formating
#define PRINTF_LEFT_ALIGN		0x0001	/**< left justify */
#define PRINTF_UPPERCASE		0x0002	/**< use A-F instead of a-f for hex */
#define PRINTF_SIGNED			0x0004	/**< signed numeric conversion (%d vs. %u) */
#define PRINTF_NEGATIVE			0x0008	/**< PRINTF_SIGNED set and num was < 0 */
#define PRINTF_ZERO_PAD			0x0010	/**< pad left with '0' instead of ' ' */
#define PRINTF_SHOW_SIGN		0x0020	/**< Always show sign */
#define PRINTF_PAD_SIGN			0x0040	/**< Pad space for sign */
#define PRINTF_ALTERNATE		0x0080	/**< Alternate form */
#define PRINTF_NUMBER			0x0100	/**< Printing number */
// Int sizes
#define PRINTF_SIZE_INT			0		/**< Default, int argument */
#define PRINTF_SIZE_CHAR		1		/**< Char argument (promoted to int) */
#define PRINTF_SIZE_SHORT		2		/**< Short argument (promoted to int) */
#define PRINTF_SIZE_LONG		3		/**< Long argument */
#define PRINTF_SIZE_LONG_LONG	4		/**< Long long argument */
#define PRINTF_SIZE_SIZE_T		5		/**< size_t argument */
#define PRINTF_SIZE_INTMAX_T	6		/**< intmax_t argument */

/**
 * Number of chars needed to represent 2^intmax_t in base 8 plus NULL
 */
#define PRINTF_BUFLEN			(((sizeof(intmax_t) * 8) / 8) + 1)

/**
 * Type of the callback function
 * @param c				Character to output
 * @param arg1			Pointer to argument 1
 * @param arg2			Pointer to argument 2
 */
typedef void(*printf_putc)(char c, void **arg1, void **arg2);

/**
 * Macro to create printf putc function
 * @param name			Symbol name
 */
#define PRINTF_PUTC(name) \
	void name(char c, void **arg1, void **arg2)

/**
 * Format string and output, calls putc for outputting.
 * @param format		String format
 * @param ...			Arguments
 * @return				Number of characters outputted
 */
int printf(const char *format, ...) __attribute__ ((format(printf, 1, 2)));

/**
 * Format string and store result in buffer.
 * @param buffer		Buffer to output to
 * @param size			Max size of buffer
 * @param format		String format
 * @param ...			Arguments
 */
int snprintf(char *buffer, size_t size, const char *format, ...) __attribute__ ((format(printf, 3, 4)));

/**
 * Same as printf() except takes arguments in va_list
 * @param format		String format
 * @param ap			Arguments
 */
int vprintf(const char *format, va_list ap);

/**
 * Same as snprintf() except takes arguments in va_list
 * @param buffer		Buffer to output to
 * @param size			Max size of buffer
 * @param format		String format
 * @param ap			Arguments
 */
int vsnprintf(char *buffer, size_t size, const char *format, va_list ap);

/**
 * Internal printf implementation, process format and call callback to do outputting
 * @param format		Printf format
 * @param ap			Variable argument list
 * @param callback		Callback function to do outputting
 * @param arg1			Argument 1 to callback
 * @param arg2			Argument 2 to callback
 * @return				Number of chars in the output string
 */
int printf_internal(const char *format, va_list ap, printf_putc callback, void *arg1, void *arg2);

/**
 * Print character, called by printf for outputting.
 * @note				Needs to be implemented by the user
 * @param c				Character to output
 * @param arg1			Pointer to argument 1, unused
 * @param arg2			Pointer to argument 2, unused
 */
void putc(char c, void **arg1, void **arg2);

#endif // !__ADDON_PRINTF_H__
//! @}
