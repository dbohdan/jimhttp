# HTML entity list.

# The contents of the dictionary html::entities is taken verbatim from
# Tcllib's html package, which bears the following copyright notice:

# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2006 Michael Schlenker <mic42@users.sourceforge.net>
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# Originally by Brent Welch, with help from Dan Kuchler and Melissa Chawla

# The text of "license.terms" is as follows:

# This software is copyrighted by Ajuba Solutions and other parties.
# The following terms apply to all files associated with the software unless
# explicitly disclaimed in individual files.
#
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.
#
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY
# FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
# ARISING OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY
# DERIVATIVES THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR
# MODIFICATIONS.
#
# GOVERNMENT USE: If you are acquiring this software on behalf of the
# U.S. government, the Government shall have only "Restricted Rights"
# in the software and related documentation as defined in the Federal
# Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
# are acquiring the software on behalf of the Department of Defense, the
# software shall be classified as "Commercial Computer Software" and the
# Government shall have only "Restricted Rights" as defined in Clause
# 252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing, the
# authors grant the U.S. Government and others acting in its behalf
# permission to use and distribute the software in accordance with the
# terms specified in this license.
namespace eval ::html {}

set ::html::entities [dict create {*}{
    \xa0 &nbsp; \xa1 &iexcl; \xa2 &cent; \xa3 &pound; \xa4 &curren;
    \xa5 &yen; \xa6 &brvbar; \xa7 &sect; \xa8 &uml; \xa9 &copy;
    \xaa &ordf; \xab &laquo; \xac &not; \xad &shy; \xae &reg;
    \xaf &macr; \xb0 &deg; \xb1 &plusmn; \xb2 &sup2; \xb3 &sup3;
    \xb4 &acute; \xb5 &micro; \xb6 &para; \xb7 &middot; \xb8 &cedil;
    \xb9 &sup1; \xba &ordm; \xbb &raquo; \xbc &frac14; \xbd &frac12;
    \xbe &frac34; \xbf &iquest; \xc0 &Agrave; \xc1 &Aacute; \xc2 &Acirc;
    \xc3 &Atilde; \xc4 &Auml; \xc5 &Aring; \xc6 &AElig; \xc7 &Ccedil;
    \xc8 &Egrave; \xc9 &Eacute; \xca &Ecirc; \xcb &Euml; \xcc &Igrave;
    \xcd &Iacute; \xce &Icirc; \xcf &Iuml; \xd0 &ETH; \xd1 &Ntilde;
    \xd2 &Ograve; \xd3 &Oacute; \xd4 &Ocirc; \xd5 &Otilde; \xd6 &Ouml;
    \xd7 &times; \xd8 &Oslash; \xd9 &Ugrave; \xda &Uacute; \xdb &Ucirc;
    \xdc &Uuml; \xdd &Yacute; \xde &THORN; \xdf &szlig; \xe0 &agrave;
    \xe1 &aacute; \xe2 &acirc; \xe3 &atilde; \xe4 &auml; \xe5 &aring;
    \xe6 &aelig; \xe7 &ccedil; \xe8 &egrave; \xe9 &eacute; \xea &ecirc;
    \xeb &euml; \xec &igrave; \xed &iacute; \xee &icirc; \xef &iuml;
    \xf0 &eth; \xf1 &ntilde; \xf2 &ograve; \xf3 &oacute; \xf4 &ocirc;
    \xf5 &otilde; \xf6 &ouml; \xf7 &divide; \xf8 &oslash; \xf9 &ugrave;
    \xfa &uacute; \xfb &ucirc; \xfc &uuml; \xfd &yacute; \xfe &thorn;
    \xff &yuml; \u192 &fnof; \u391 &Alpha; \u392 &Beta; \u393 &Gamma;
    \u394 &Delta; \u395 &Epsilon; \u396 &Zeta; \u397 &Eta; \u398 &Theta;
    \u399 &Iota; \u39A &Kappa; \u39B &Lambda; \u39C &Mu; \u39D &Nu;
    \u39E &Xi; \u39F &Omicron; \u3A0 &Pi; \u3A1 &Rho; \u3A3 &Sigma;
    \u3A4 &Tau; \u3A5 &Upsilon; \u3A6 &Phi; \u3A7 &Chi; \u3A8 &Psi;
    \u3A9 &Omega; \u3B1 &alpha; \u3B2 &beta; \u3B3 &gamma; \u3B4 &delta;
    \u3B5 &epsilon; \u3B6 &zeta; \u3B7 &eta; \u3B8 &theta; \u3B9 &iota;
    \u3BA &kappa; \u3BB &lambda; \u3BC &mu; \u3BD &nu; \u3BE &xi;
    \u3BF &omicron; \u3C0 &pi; \u3C1 &rho; \u3C2 &sigmaf; \u3C3 &sigma;
    \u3C4 &tau; \u3C5 &upsilon; \u3C6 &phi; \u3C7 &chi; \u3C8 &psi;
    \u3C9 &omega; \u3D1 &thetasym; \u3D2 &upsih; \u3D6 &piv;
    \u2022 &bull; \u2026 &hellip; \u2032 &prime; \u2033 &Prime;
    \u203E &oline; \u2044 &frasl; \u2118 &weierp; \u2111 &image;
    \u211C &real; \u2122 &trade; \u2135 &alefsym; \u2190 &larr;
    \u2191 &uarr; \u2192 &rarr; \u2193 &darr; \u2194 &harr; \u21B5 &crarr;
    \u21D0 &lArr; \u21D1 &uArr; \u21D2 &rArr; \u21D3 &dArr; \u21D4 &hArr;
    \u2200 &forall; \u2202 &part; \u2203 &exist; \u2205 &empty;
    \u2207 &nabla; \u2208 &isin; \u2209 &notin; \u220B &ni; \u220F &prod;
    \u2211 &sum; \u2212 &minus; \u2217 &lowast; \u221A &radic;
    \u221D &prop; \u221E &infin; \u2220 &ang; \u2227 &and; \u2228 &or;
    \u2229 &cap; \u222A &cup; \u222B &int; \u2234 &there4; \u223C &sim;
    \u2245 &cong; \u2248 &asymp; \u2260 &ne; \u2261 &equiv; \u2264 &le;
    \u2265 &ge; \u2282 &sub; \u2283 &sup; \u2284 &nsub; \u2286 &sube;
    \u2287 &supe; \u2295 &oplus; \u2297 &otimes; \u22A5 &perp;
    \u22C5 &sdot; \u2308 &lceil; \u2309 &rceil; \u230A &lfloor;
    \u230B &rfloor; \u2329 &lang; \u232A &rang; \u25CA &loz;
    \u2660 &spades; \u2663 &clubs; \u2665 &hearts; \u2666 &diams;
    \x22 &quot; \x26 &amp; \x3C &lt; \x3E &gt; \u152 &OElig;
    \u153 &oelig; \u160 &Scaron; \u161 &scaron; \u178 &Yuml;
    \u2C6 &circ; \u2DC &tilde; \u2002 &ensp; \u2003 &emsp; \u2009 &thinsp;
    \u200C &zwnj; \u200D &zwj; \u200E &lrm; \u200F &rlm; \u2013 &ndash;
    \u2014 &mdash; \u2018 &lsquo; \u2019 &rsquo; \u201A &sbquo;
    \u201C &ldquo; \u201D &rdquo; \u201E &bdquo; \u2020 &dagger;
    \u2021 &Dagger; \u2030 &permil; \u2039 &lsaquo; \u203A &rsaquo;
    \u20AC &euro;
}]
