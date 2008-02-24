# Copyright(c) 1986 Association of Universities for Research in Astronomy Inc.

# SYS_PANIC -- Unconditionally abort process execution.  Called when an error
# condition occurs so serious that process execution cannot continue reliably.

procedure sys_panic (errcode, errmsg)

int	errcode			# error code
char	errmsg[ARB]		# error message

size_t	sz_val

begin
	# Since process termination is imminent we may as well overwrite the
	# error message string by packing it in place.

	sz_val = ARB
	call strpak (errmsg, errmsg, sz_val)
	call zpanic (errcode, errmsg)
end
