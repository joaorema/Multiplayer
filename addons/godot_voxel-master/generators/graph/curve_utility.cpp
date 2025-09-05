#include "curve_utility.h"
#include "../../util/godot/classes/curve.h"
#include "../../util/math/vector2i.h"
#include "../../util/string/format.h"

namespace zylann {

using namespace math;

void get_curve_monotonic_sections(Curve &curve, StdVector<CurveMonotonicSection> &sections) {
	const Interval curve_domain = zylann::godot::get_curve_domain(curve);
	const float curve_domain_range = curve_domain.length();

	const int res = curve.get_bake_resolution();
	float prev_y = curve.sample_baked(curve_domain.min);

	sections.clear();
	CurveMonotonicSection section;
	section.x_min = curve_domain.min;
	section.y_min = curve.sample_baked(curve_domain.min);

	float prev_x = 0.f;
	bool current_stationary = true;
	bool current_increasing = false;

	// Iterating up to `res` included, to include the final value (Godot's PR #76617 fixed an issue in Curve, which also
	// made it apparent that our code didn't properly include the end of the curve)
	for (int i = 1; i < res; ++i) {
		// We do -1 because [res-1] is the last value in the baked array, therefore `x` must be 1
		const float x = curve_domain.min + curve_domain_range * static_cast<float>(i) / (res - 1);
		const float y = curve.sample_baked(x);
		// Curve can sometimes appear flat but it still oscillates by very small amounts due to float imprecision
		// which occurred during bake(). Attempting to workaround that by taking the error into account
		const bool increasing = y > prev_y + CURVE_RANGE_MARGIN;
		const bool decreasing = y < prev_y - CURVE_RANGE_MARGIN;
		const bool stationary = increasing == false && decreasing == false;

		if (current_stationary) {
			current_stationary = stationary;
			current_increasing = increasing;

		} else if (i > 1 && !stationary && increasing != current_increasing) {
			section.x_max = prev_x;
			section.y_max = prev_y;
			sections.push_back(section);

			section.x_min = prev_x;
			section.y_min = prev_y;
			current_increasing = increasing;
			// Note, `current_stationary` does not become true ever again, because we only care about varying sections.
			// If a part of the curve becomes stationary, it will be included within the current section until it
			// starts increasing or decreasing.
		}

		prev_x = x;
		prev_y = y;
	}

	// Forcing max because the iteration doesn't go up to `res`
	section.x_max = curve_domain.max;
	section.y_max = prev_y;
	sections.push_back(section);
}

Interval get_curve_range(Curve &curve, const StdVector<CurveMonotonicSection> &sections, Interval x) {
	// This implementation is linear. It assumes curves usually don't have many points.
	// If a curve has too many points, we may consider dynamically choosing a different algorithm.
	Interval y;
	unsigned int i = 0;
	const float x_min = sections[0].x_min;
	if (x.min < x_min) {
		// X range starts before the curve's minimum X
		y = Interval::from_single_value(curve.sample_baked(x_min));
	} else {
		// Find section from where the range starts
		for (; i < sections.size(); ++i) {
			const CurveMonotonicSection &section = sections[i];
			if (x.min >= section.x_min) {
				const float begin_y = curve.sample_baked(x.min);
				if (x.max < section.x_max) {
					// X range starts and ends in that section
					return Interval::from_unordered_values(begin_y, curve.sample_baked(x.max))
							.padded(CURVE_RANGE_MARGIN);
				} else {
					// X range starts in that section, and continues after it.
					// Will need to keep iterating, starting from here
					y = Interval::from_unordered_values(begin_y, curve.sample_baked(section.x_max));
					++i;
					break;
				}
			}
		}
	}
	for (; i < sections.size(); ++i) {
		const CurveMonotonicSection &section = sections[i];
		if (x.max >= section.x_max) {
			// X range covers this whole section and maybe more after it
			y.add_interval(Interval::from_unordered_values(section.y_min, section.y_max));
		} else {
			// X range ends in that section
			y.add_interval(Interval::from_unordered_values(section.y_min, curve.sample_baked(x.max)));
			break;
		}
	}
	return y.padded(CURVE_RANGE_MARGIN);
}

Interval get_curve_range(Curve &curve, bool &is_monotonic_increasing) {
	// TODO Would be nice to have the cache directly
	const int res = curve.get_bake_resolution();
	Interval range;
	const Interval curve_domain = zylann::godot::get_curve_domain(curve);
	const float curve_domain_range = curve_domain.length();
	float prev_v = curve.sample_baked(curve_domain.min);
	if (curve.sample_baked(curve_domain.max) > prev_v) {
		is_monotonic_increasing = true;
	}
	for (int i = 0; i < res; ++i) {
		const float a = curve_domain.min + curve_domain_range * static_cast<float>(i) / res;
		const float v = curve.sample_baked(a);
		range.add_point(v);
		if (v < prev_v) {
			is_monotonic_increasing = false;
		}
		prev_v = v;
	}
	return range;
}

} // namespace zylann
