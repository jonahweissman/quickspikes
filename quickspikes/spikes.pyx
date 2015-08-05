# -*- coding: utf-8 -*-
# -*- mode: cython -*-
"""spike detection routines

Copyright (C) 2013 Dan Meliza <dmeliza@gmail.com>
Created Wed Jul 24 09:26:36 2013
"""
from cython.view cimport array as cvarray

cdef enum DetectorState:
    BELOW_THRESHOLD = 1
    BEFORE_PEAK = 2
    AFTER_PEAK = 3

cdef inline bint compare_sign(double x, double y):
    """return True iff ((x > 0) && (y > 0)) || ((x < 0) && (y < 0))"""
    return ((x >= 0) and (y >= 0)) or ((x < 0) and (y < 0))

cdef class detector:
    """Detect spikes in a continuous stream of samples.

    This implementation allows samples to be sent to the detector in blocks, and
    maintains state across successive calls.
    """
    cdef:
        double thresh
        double scaled_thresh
        double prev_val
        int n_after
        int n_after_crossing
        DetectorState state

    def __init__(self, double thresh, int n_after):
        """Construct spike detector.

        Parameters
        ----------
        thresh : double
          The crossing threshold that triggers the detector. NB: to detect
          negative-going peaks, invert the signal sent to send()
        n_after : int
          The maximum number of samples after threshold crossing to look for the
          peak. If a peak has not been located within this window, the crossing
          is considered an artifact and is not counted.

        """
        self.thresh = self.scaled_thresh = thresh
        self.n_after = n_after
        self.reset()

    def scale_thresh(self, double mean, double sd):
        """Adjust threshold for the mean and standard deviation of the signal.

        The effective threshold will be (thresh * sd + mean)

        """
        self.scaled_thresh = self.thresh * sd + mean

    def send(self, double[:] samples):
        """Detect spikes in a time series.

        Returns a list of indices corresponding to the peaks (or troughs) in the
        data. Retains state between calls. The detector should be reset if there
        is a gap in the signal.

        """
        cdef double x
        cdef int i = 0
        out = []

        for i in range(samples.shape[0]):
            x = samples[i]
            if self.state is BELOW_THRESHOLD:
                if x >= self.scaled_thresh:
                    self.prev_val = x
                    self.n_after_crossing = 0
                    self.state = BEFORE_PEAK
            elif self.state is BEFORE_PEAK:
                if self.prev_val > x:
                    out.append(i - 1)
                    self.state = AFTER_PEAK
                elif self.n_after_crossing > self.n_after:
                    self.state = BELOW_THRESHOLD
                else:
                    self.prev_val = x
                    self.n_after_crossing += 1
            elif self.state is AFTER_PEAK:
                if x < self.scaled_thresh:
                    self.state = BELOW_THRESHOLD
        return out

    def reset(self):
        """Reset the detector's internal state"""
        self.state = BELOW_THRESHOLD


def peaks(double[:] samples, times, int n_before=75, int n_after=400):
    """Extracts samples around times

    Returns a 2D array with len(times) rows and (n_before + n_after) columns
    containing the values surrounding the sample indices in times.

    """
    cdef int i = 0
    cdef int event
    cdef double [:, :] out = cvarray(shape=(len(times), n_before + n_after),
                                     itemsize=sizeof(double), format="d")
    for event in times:
        if (event - n_before < 0) or (event + n_after > samples.size):
            continue
        else:
            out[i,:] = samples[event-n_before:event+n_after]
            i += 1

    return out[:i,:]


def subthreshold(double[:] samples, times,
                 double v_thresh=-50, double dv_thresh=0, min_size=10):
    """Removes spikes from time series

    Spikes are removed from the voltage trace by beginning at each peak and
    moving in either direction until V drops below thresh_v OR dv drops below
    thresh_dv. This algorithm does not work with negative peaks, so invert your
    signal if you need to.

    - samples : signal to analyze
    - times : times of the peaks (in samples)
    - thresh_v : do not include points contiguous with the peak with V > thresh_v
    - thresh_dv : do not include points contiguous with the peak with deltaV > thresh_dv.
                  negative values correspond to positive-going voltages
    - min_size : always remove at least this many points on either side of peak

    Returns a copy of samples with the data points around spike times set to NaN

    """
    pass




# Variables:
# End:
