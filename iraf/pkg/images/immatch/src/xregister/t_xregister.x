include <imhdr.h>
include <fset.h>
include <gset.h>
include <imset.h>
include "xregister.h"

# T_XREGISTER -- Register a list of images using cross-correlation techniques.

procedure t_xregister()

pointer	freglist		# reference regions list
pointer	database		# the shifts database
int	dformat			# use the database format for the shifts file ?
int	interactive		# interactive mode ?
int	verbose			# verbose mode
pointer	interpstr		# interpolant type
int	boundary		# boundary extension type
real	constant		# constant for boundary extension

size_t	sz_val
int	i_val
int	tfd, stat, nregions
long	c1, c2, l1, l2, ncols, nlines
pointer	reglist, reflist, reclist, list1, listr, list2
pointer	sp, image1, image2, imtemp, str, coords
pointer	gd, id, imr, im1, im2, sdb, xc, mw
real	shifts[2]
bool	clgetb()
int	imtlen(), imtgetim(), clgwrd(), btoi()
int	rg_xregions(), fntlenb(), rg_gxtransform(), rg_xstati()
int	rg_xcorr(), rg_xicorr(), fntgfnb(), access(), open()
pointer	fntopnb(), imtopen(), gopen(), immap(), dtmap(), mw_openim()
real	clgetr(), rg_xstatr()
errchk	fntopnb(), gopen()
include	<nullptr.inc>

begin
	# Set STDOUT to flush on a newline character
	call fseti (STDOUT, F_FLUSHNL, YES)

	# Allocate temporary working space.
	call smark (sp)

	sz_val = SZ_LINE
	call salloc (freglist, sz_val, TY_CHAR)
	sz_val = SZ_FNAME
	call salloc (image1, sz_val, TY_CHAR)
	call salloc (image2, sz_val, TY_CHAR)
	call salloc (imtemp, sz_val, TY_CHAR)
	call salloc (database, sz_val, TY_CHAR)
	call salloc (coords, sz_val, TY_CHAR)
	call salloc (interpstr, sz_val, TY_CHAR)
	sz_val = SZ_LINE
	call salloc (str, sz_val, TY_CHAR)

	# Get task parameters and open lists.
	call clgstr ("input", Memc[str], SZ_LINE)
	list1 = imtopen (Memc[str])
	call clgstr ("reference", Memc[str], SZ_LINE)
	listr = imtopen (Memc[str])
	call clgstr ("regions", Memc[freglist], SZ_LINE)
	call clgstr ("shifts", Memc[database], SZ_FNAME)
	call clgstr ("output", Memc[str], SZ_LINE)
	list2 = imtopen (Memc[str])
	call clgstr ("records", Memc[str], SZ_LINE)
	if (Memc[str] == EOS)
	    reclist = NULL
	else
	    reclist = fntopnb (Memc[str], NO)
	call clgstr ("coords", Memc[coords], SZ_LINE)

	# Open the cross correlation fitting structure.
	call rg_xgpars (xc)

	# Test the reference image list length.
	if (rg_xstati (xc, CFUNC) != XC_FILE) {
	    if (imtlen (listr) <= 0)
	        call error (0, "The reference image list is empty.")
	    if (imtlen (listr) > 1 && imtlen (listr) != imtlen (list1))
	        call error (0,
	            "The number of reference and input images is not the same.")
	    if (Memc[coords] == EOS)
	        reflist = NULL
	    else {
	        reflist = fntopnb (Memc[coords], NO)
		if (imtlen (listr) != fntlenb (reflist))
	            call error (0,
	      "The number of reference point files and images is not the same.")
	   }
	    iferr {
	        reglist = fntopnb (Memc[freglist], NO)
	    } then {
	        reglist = NULL
	    }
	    call rg_xsets (xc, REGIONS, Memc[freglist])

	} else {
	    call imtclose (listr)
	    listr = NULL
	    reflist = NULL
	    reglist = NULL
	    call rg_xsets (xc, REGIONS, "")
	}

	# Close the output image list if it is empty.
	if (imtlen (list2) == 0) {
	    call imtclose (list2)
	    list2 = NULL
	}

	# Check that the output image list is the same size as the input
	# image list.
	if (list2 != NULL) {
	    if (imtlen (list1) != imtlen (list2)) {
	        call imtclose (list1)
	        if (list2 != NULL)
	            call imtclose (list2)
	       call error (0,
	           "The number of input and output images is not the same.")
	    }
	}

	# Check that the record list is the same length as the input
	# image list length.
	if (reclist != NULL) {
	    if (fntlenb (reclist) != imtlen (list1))
	        call error (0,
	            "Input image and record lists are not the same length.")
	}


	# Open the database file.
	dformat = btoi (clgetb ("databasefmt"))
	if (rg_xstati (xc, CFUNC) == XC_FILE) {
	    if (dformat == YES)
	        sdb = dtmap (Memc[database], READ_ONLY)
	    else
		sdb = open (Memc[database], READ_ONLY, TEXT_FILE)
	} else if (clgetb ("append")) {
	    if (dformat == YES)
	        sdb = dtmap (Memc[database], APPEND)
	    else
		sdb = open (Memc[database], NEW_FILE, TEXT_FILE)
	} else if (access (Memc[database], 0, 0) == YES) {
	    call error (0, "The shifts database file already exists")
	} else {
	    if (dformat == YES)
	        sdb = dtmap (Memc[database], NEW_FILE)
	    else
		sdb = open (Memc[database], NEW_FILE, TEXT_FILE)
	}
	call rg_xsets (xc, DATABASE, Memc[database])

	# Get the boundary extension parameters for the image shift.
	call clgstr ("interp_type", Memc[interpstr], SZ_FNAME)
	boundary = clgwrd ("boundary_type", Memc[str], SZ_LINE,
	   "|constant|nearest|reflect|wrap|")
	constant = clgetr ("constant")

	if (rg_xstati (xc, CFUNC) == XC_FILE)
	    interactive = NO
	else
	    interactive = btoi (clgetb ("interactive"))
	if (interactive == YES) {
	    call clgstr ("graphics", Memc[str], SZ_FNAME)
	    iferr (gd = gopen (Memc[str], NEW_FILE, STDGRAPH))
		gd = NULL
	    call clgstr ("display", Memc[str], SZ_FNAME)
	    iferr (id = gopen (Memc[str], APPEND, STDIMAGE))
		id = NULL
	    verbose = YES
	} else {
	    if (rg_xstati (xc, PFUNC) == XC_MARK)
		call rg_xseti (xc, PFUNC, XC_CENTROID)
	    gd = NULL
	    id = NULL
	    verbose = btoi (clgetb ("verbose"))
	}

	# Initialize the reference image filter descriptors
	imr = NULL
	tfd = NULL

	# Initialize the overlap section.
	c1 = INDEFL
	c2 = INDEFL
	l1 = INDEFL
	l2 = INDEFL
	ncols = INDEFL
	nlines = INDEFL

	# Do each set of input, reference,  and output images.
	while ((imtgetim (list1, Memc[image1], SZ_FNAME) != EOF)) {

	    # Open the reference image, and associated regions and coordinates
	    # files if the correlation function is not file.

	    if (rg_xstati (xc, CFUNC) != XC_FILE) {
	        if (imtgetim (listr, Memc[str], SZ_FNAME) != EOF) {
		    if (imr != NULL)
		        call imunmap (imr)
		    imr = immap (Memc[str], READ_ONLY, NULLPTR)
		    if (IM_NDIM(imr) > 2)
		        call error (0, "Reference images must be 1D or 2D")
		    call rg_xsets (xc, REFIMAGE, Memc[str])
		    nregions = rg_xregions (reglist, imr, xc, 1)
		    if (nregions <= 0 && interactive == NO)
		        call error (0, "The regions list is empty.")
		    if (reflist != NULL) {
		        if (tfd != NULL)
			    call close (tfd)
		        tfd = rg_gxtransform (reflist, xc, Memc[str])
		        call rg_xsets (xc, REFFILE, Memc[str])
		    }
	        }
	    } else
		call rg_xsets (xc, REFIMAGE, "reference")

	    # Open the input image.
	    im1 = immap (Memc[image1], READ_ONLY, NULLPTR)
	    if (IM_NDIM(im1) > 2) {
	         call error (0, "Input images must be 1D or 2D")
	    } else if (imr != NULL) {
	        if (IM_NDIM(im1) != IM_NDIM(imr))
		    call error (0,
	      "Input images must have same dimensionality as reference images")
	    }
	    call imseti (im1, IM_TYBNDRY, BT_NEAREST)
	    if (IM_NDIM(im1) == 1)
	        call imsetl (im1, IM_NBNDRYPIX, IM_LEN(im1,1))
	    else
	        call imsetl (im1, IM_NBNDRYPIX,
		    max (IM_LEN(im1,1), IM_LEN(im1,2)))
	    call rg_xsets (xc, IMAGE, Memc[image1])

	    # Open the output image if any.
	    if (list2 == NULL) {
	        im2 = NULL
		Memc[image2] = EOS
	    } else if (imtgetim (list2, Memc[image2], SZ_FNAME) != EOF) {
		call xt_mkimtemp (Memc[image1], Memc[image2], Memc[imtemp],
		    SZ_FNAME)
	        im2 = immap (Memc[image2], NEW_COPY, im1)
	    } else {
	        im2 = NULL
		Memc[image2] = EOS
	    }
	    call rg_xsets (xc, OUTIMAGE, Memc[image2])

	    # Get the image record name for the shifts database.
	    if (reclist == NULL)
		call strcpy (Memc[image1], Memc[str], SZ_FNAME)
	    else if (fntgfnb (reclist, Memc[str], SZ_FNAME) == EOF)
		call strcpy (Memc[image1], Memc[str], SZ_FNAME)
	    call rg_xsets (xc, RECORD, Memc[str])

	    # Compute the initial coordinate shift.
	    if (tfd != NULL)
		call rg_xtransform (tfd, xc)

	    # Perform the cross correlation function.
	    if (interactive == YES) {
		stat = rg_xicorr (imr, im1, im2, sdb, dformat, reglist, tfd,
		    xc, gd, id)
	    } else {
	        stat = rg_xcorr (imr, im1, sdb, dformat, xc)
		if (verbose == YES) {
		    call rg_xstats (xc, REFIMAGE, Memc[str], SZ_LINE)
	            call printf (
		        "Average shift from %s to %s is %g %g pixels\n")
	                call pargstr (Memc[image1])
	                call pargstr (Memc[str])
	                call pargr (rg_xstatr (xc, TXSHIFT))
	                call pargr (rg_xstatr (xc, TYSHIFT))
		}
	    }

	    # Compute the overlap region for the images.
	    call rg_overlap (im1, rg_xstatr (xc, TXSHIFT),
	        rg_xstatr (xc,TYSHIFT), c1, c2, l1, l2, ncols, nlines)

	    # Shift the image and update the wcs.
	    if (im2 != NULL && stat == NO) {
		if (verbose == YES) {
		    call printf (
		        "\tShifting image %s to image %s ...\n")
		        call pargstr (Memc[image1])
			call pargstr (Memc[imtemp])
		}

		call rg_xshiftim (im1, im2, rg_xstatr (xc, TXSHIFT),
		    rg_xstatr (xc, TYSHIFT), Memc[interpstr], boundary,
		        constant)
		mw = mw_openim (im1)
		shifts[1] = rg_xstatr (xc, TXSHIFT)
		shifts[2] = rg_xstatr (xc, TYSHIFT)
		call mw_shift (mw, shifts, 03B)
		call mw_saveim (mw, im2)
		call mw_close (mw)
	    }

	    # Close up the input and output images.
	    call imunmap (im1)
	    if (im2 != NULL) {
		call imunmap (im2)
	        if (stat == YES)
		    call imdelete (Memc[image2])
		else
		    call xt_delimtemp (Memc[image2], Memc[imtemp])
	    }

	    if (stat == YES)
		break
	    call rg_xindefr (xc)
	}

	if (verbose == YES)
	    call rg_poverlap (c1, c2, l1, l2, ncols, nlines)

	call rg_xfree (xc)

	# Close up the lists.
	if (imr != NULL)
	    call imunmap (imr)
	call imtclose (list1)
	if (listr != NULL)
	    call imtclose (listr)
	if (reglist != NULL)
	    call fntclsb (reglist)
	if (list2 != NULL)
	    call imtclose (list2)
	if (tfd != NULL)
	    call close (tfd)
	if (reflist != NULL)
	    call fntclsb (reflist)
	if (reclist != NULL)
	    call fntclsb (reclist)
	if (dformat == YES) {
	    call dtunmap (sdb)
	} else {
	    i_val = sdb
	    call close (i_val)
	}

	# Close up the graphics and display devices.
	if (gd != NULL)
	    call gclose (gd)
	if (id != NULL)
	    call gclose (id)

	call sfree (sp)
end


# RG_OVERLAP -- Compute the overlap region of the list of images.

procedure rg_overlap (im1, xshift, yshift, x1, x2, y1, y2, ncols, nlines)

pointer	im1			# pointer to the input image
real	xshift			# the computed x shift of the input image
real	yshift			# the computed y shift of the input image
long	x1, x2			# the input/output column limits
long	y1, y2			# the input/output line limits
long	ncols, nlines		# the input/output size limits

long	ixlo, ixhi, iylo, iyhi
real	xlo, xhi, ylo, yhi

long	lint()

begin
	if (IS_INDEFR(xshift) || IS_INDEFR(yshift))
	    return

	# Compute the limits of the shifted image.
	xlo = 1.0 + xshift
	xhi = IM_LEN(im1,1) + xshift
	ylo = 1.0 + yshift
	yhi = IM_LEN(im1,2) + yshift

	# Round up or down as appropriate.
	ixlo = lint(xlo)
	if (xlo > ixlo)
	    ixlo = ixlo + 1
	ixhi = lint(xhi)
	if (xhi < ixhi)
	    ixhi = ixhi - 1
	iylo = lint(ylo)
	if (ylo > iylo)
	    iylo = iylo + 1
	iyhi = lint(yhi)
	if (yhi < iyhi)
	    iyhi = iyhi - 1

	# Determine the new limits.
	if (IS_INDEFL(x1))
	    x1 = ixlo
	else
	    x1 = max (ixlo, x1)
	if (IS_INDEFL(x2))
	    x2 = ixhi
	else
	    x2 = min (ixhi, x2)
	if (IS_INDEFL(y1))
	    y1 = iylo
	else
	    y1 = max (iylo, y1)
	if (IS_INDEFL(y2))
	    y2 = iyhi
	else
	    y2 = min (iyhi, y2)
	if (IS_INDEFL(ncols))
	    ncols = IM_LEN(im1,1)
	else
	    ncols = min (ncols, IM_LEN(im1,1))
	if (IS_INDEFL(nlines))
	    nlines = IM_LEN(im1,2)
	else
	    nlines = min (nlines, IM_LEN(im1,2))
end


# RG_POVERLAP -- Procedure to print the overlap and/or vignetted region.

procedure rg_poverlap (x1, x2, y1, y2, ncols, nlines)

long	x1, x2			# the input column limits
long	y1, y2			# the input line limits
long	ncols, nlines		# the number of lines and columns

long	vx1, vx2, vy1, vy2

begin
	vx1 = max (1, min (x1, ncols))
	vx2 = max (1, min (x2, ncols))
	vy1 = max (1, min (y1, nlines))
	vy2 = max (1, min (y2, nlines))

	call printf ("Overlap region: [%d:%d,%d:%d]\n")
	    call pargl (x1)
	    call pargl (x2)
	    call pargl (y1)
	    call pargl (y2)
	if (vx1 != x1 || vx2 != x2 || vy1 != y1 || vy2 != y2) {
	    call printf ("Vignetted overlap region: [%d:%d,%d:%d]\n")
	        call pargl (vx1)
	        call pargl (vx2)
	        call pargl (vy1)
	        call pargl (vy2)
	}
end
