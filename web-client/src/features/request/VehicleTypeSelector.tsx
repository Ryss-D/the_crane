import { VEHICLE_TYPES } from '../../api/types';
import type { VehicleType } from '../../api/types';
import { strings } from '../../i18n/strings';

const icons: Record<VehicleType, string> = { moto: '🏍️', car: '🚗', suv: '🚙' };

export function VehicleTypeSelector({
  value,
  onChange,
}: {
  value: VehicleType | null;
  onChange: (v: VehicleType) => void;
}) {
  return (
    <div
      role="radiogroup"
      aria-label={strings.request.vehicleTypeLabel}
      className="grid grid-cols-3 gap-2"
    >
      {VEHICLE_TYPES.map((type) => {
        const selected = value === type;
        return (
          <button
            key={type}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(type)}
            className={`flex flex-col items-center gap-1 rounded-xl border px-2 py-3 text-sm font-semibold transition-colors ${
              selected
                ? 'border-amber-500 bg-amber-500/10 text-amber-300'
                : 'border-slate-700 bg-slate-800 text-slate-300 hover:border-slate-500'
            }`}
          >
            <span aria-hidden className="text-2xl">
              {icons[type]}
            </span>
            {strings.vehicleTypes[type]}
          </button>
        );
      })}
    </div>
  );
}
