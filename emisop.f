C $Id: emisop.f,v 1.3 2004/03/05 21:15:39 bmy Exp $      
      FUNCTION EMISOP( I, J, IJLOOP, SUNCOS, TMMP, XNUMOL )
!
!******************************************************************************
!  Subroutine EMISOP_GRASS computes ISOPRENE EMISSIONS in units of 
!  [atoms C/box/step]. (bdf, bmy, 8/1/01, 3/5/04)
!
!  Arguments as Input:
!  ============================================================================
!  (1-2) I, J     (INTEGER ) : 2-D grid box indices
!  (3 ) IJLOOP    (INTEGER ) : 1-D grid box index
!  (4 ) SUNCOS    (REAL*8  ) : 1-D array of cos( solar zenith angle )
!  (5 ) TMMP      (REAL*8  ) : Local air temperature (K)
!  (6 ) XNUMOL    (REAL*8  ) : Number of atoms C / kg C 
!
!  Important Common Block Variables:
!  ============================================================================
!  (1 ) XYLAI     (CMN_VEL ) : Leaf Area Index of land type for current MONTH
!  (2 ) IJREG     (CMN_VEL ) : Number of Olson land types per grid box
!  (3 ) IJLAND+1  (CMN_VEL ) : Olson land type index
!  (4 ) IJUSE     (CMN_VEL ) : Olson land type fraction per box (in mils)
!  (5 ) SOPCOEFF  (CMN_ISOP) : 2nd order polynomial coeffs for light correction
!  (6 ) BASEISOP  (CMN_ISOP) : Baseline ISOPRENE emissions   [kg C/box/step]
!
!  NOTES:
!  (1 ) Now force double precision with DBLE and "D" exponents.  Also updated 
!        comments, made cosmetic changes (bmy, 4/4/03)
!  (2 ) Now pass I, J via the arg list.  Now reference CLDFRC directly from
!        "dao_mod.f" instead of referencing CFRAC from "CMN_DEP".  Now 
!        remove reference to CMN_DEP. (bmy, 12/9/03)
!  (3 ) Now scale ISOP emissions to 400 Tg C/yr for GEOS-4 (bmy, 3/5/04)
!******************************************************************************
!
      ! References to F90 modules
      USE DAO_MOD, ONLY : CLDFRC

      IMPLICIT NONE

#     include "CMN_SIZE"  ! Size parameters
#     include "CMN_VEL"   ! IJREG, IJLAND, IJUSE
#     include "CMN_ISOP"  ! SOPCOEFF, BASEISOP

      ! Arguments 
      INTEGER, INTENT(IN) :: IJLOOP,        I,    J
      REAL*8,  INTENT(IN) :: SUNCOS(MAXIJ), TMMP, XNUMOL

      ! Local variables
      INTEGER             :: INVEG
      REAL*8              :: TLAI,   EMBIO, CLIGHT

      ! External functions
      REAL*8,  EXTERNAL   :: XLTMMP, BIOFIT, TCORR

      ! Function value
      REAL*8              :: EMISOP

      !=================================================================
      ! EMISOP begins here!
      !=================================================================

      ! Initialize
      EMISOP = 0.d0
      TLAI   = 0.d0

      ! Compute total of Leaf Area Index * baseline isoprene
      ! over all Olson land types that are in this grid box      
      DO INVEG = 1, IJREG(IJLOOP)
         TLAI = TLAI + XYLAI(IJLOOP,INVEG) * BASEISOP(IJLOOP,INVEG)
      ENDDO

      !=================================================================
      ! Apply light & temperature corrections to baseline emissions --
      ! only if it is daytime and if there is nonzero isoprene emission 
      ! (e.g. XYLAI * BASEISOP > 0 )
      !=================================================================
      IF ( ( SUNCOS(IJLOOP) > 0d0 ) .AND. ( TLAI > 0d0 ) ) THEN

         ! Initialize
         EMBIO = 0d0

         ! Loop over each Olson land type in this grid box 
         DO INVEG = 1, IJREG(IJLOOP)

            ! If the product of leaf area index and baseline ISOP > 0 ...
            IF ( XYLAI(IJLOOP,INVEG) * 
     &           BASEISOP(IJLOOP,INVEG) > 0d0 ) THEN

               ! Compute light correction -- polynomial fit 
               CLIGHT = BIOFIT( SOPCOEFF,       XYLAI(IJLOOP,INVEG),
     &                          SUNCOS(IJLOOP), CLDFRC(I,J) )

               ! Apply light correction to baseline ISOPRENE emissions.
               ! Also multiply by the fraction of the grid box occupied
               ! by this Olson landtype.  Units are [kg C/box/step].
               ! BASEISOP emission rate is set in setbase.f               
               EMBIO = EMBIO + 
     &                 ( BASEISOP(IJLOOP,INVEG) * CLIGHT * 
     &                   DBLE( IJUSE(IJLOOP,INVEG) ) ) / 1000.d0
            ENDIF
         ENDDO

         ! Apply the temperature correction from Gunther et al 92 to the
         ! ISOPRENE emissions.  Units are still [kg C/box/step].
         IF ( TMMP > 273d0 ) THEN
            EMISOP = TCORR(TMMP) * EMBIO
         ELSE
            EMISOP = 0d0
         ENDIF
      ENDIF
      
      !=================================================================
      ! EMISOP is the amount of ISOP emitted in [kg/box/step]. 
      ! Convert to [atoms C/box/step] and return.
      !=================================================================
      EMISOP = EMISOP * XNUMOL

#if   defined( GEOS_3 )

      ! GEOS-3 meteorology results in 579 Tg C/yr from ISOP.
      ! Scale this down to 400 Tg C/yr, which is what we
      ! get from GEOS-STRAT (mje, djj, bmy, 8/26/02)
      EMISOP = EMISOP * ( 400d0 / 579d0 )

#else defined( GEOS_4 )

      ! GEOS-4 2003 meteorology results in 443 Tg C/yr from ISOP.
      ! Scale this down to 400 Tg C/yr, which is what we get from 
      ! GEOS-STRAT.  This will be replaced soon. (jal, bmy, 3/5/04)
      EMISOP = EMISOP * ( 400d0 / 443d0 )

#endif 

      ! Return to calling program
      END FUNCTION EMISOP
