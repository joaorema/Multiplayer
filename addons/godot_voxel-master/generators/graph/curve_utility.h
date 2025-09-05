#ifndef ZN_CURVE_UTILITY_H
#define ZN_CURVE_UTILITY_H

#include "../../util/containers/std_vector.h"
#include "../../util/godot/core/rect2i.h"
#include "../../util/godot/macros.h"
#include "../../util/math/interval.h"

ZN_GODOT_FORWARD_DECLARE(class Curve)

namespace zylann {

struct CurveMonotonicSection {
	float x_min;
	float x_max;
	// Note: Y values are not necessarily in increasing order.
	// Their name only means to correspond to X coordinates.
	float y_min;
	float y_max;
};

struct CurveRangeData {
	StdVector<CurveMonotonicSection> sections;
};

static const float CURVE_RANGE_MARGIN = CMP_EPSILON;

// Gathers monotonic sections of a curve, at baked resolution.
// Within one section, the curve has only one of the following properties:
// - Be stationary or decrease
// - Be stationary or increase
// Which means, within one section, given a range of input values defined by a min and max,
// we can quickly calculate an accurate range of output values by sampling the curve only at the two points.
void get_curve_monotonic_sections(Curve &curve, StdVector<CurveMonotonicSection> &sections);
// Gets the range of Y values for a range of X values on a curve, using precalculated monotonic segments
math::Interval get_curve_range(Curve &curve, const StdVector<CurveMonotonicSection> &sections, math::Interval x);

// Legacy
math::Interval get_curve_range(Curve &curve, bool &is_monotonic_increasing);

} // namespace zylann

#endif // ZN_CURVE_UTILITY_H
