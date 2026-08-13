import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { CommissionModeSelect } from './CommissionModeSelect';
import { strings } from '../../i18n/strings';

describe('CommissionModeSelect', () => {
  it('renders both options and reflects the current mode', () => {
    render(<CommissionModeSelect mode="percent" onChange={vi.fn()} />);

    const select = screen.getByLabelText(strings.config.fields.mode) as HTMLSelectElement;
    expect(select.value).toBe('percent');
    expect(
      screen.getByRole('option', { name: strings.config.commissionModes.percent }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole('option', { name: strings.config.commissionModes.flat }),
    ).toBeInTheDocument();
  });

  it('calls onChange with the newly selected mode', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<CommissionModeSelect mode="percent" onChange={onChange} />);

    const select = screen.getByLabelText(strings.config.fields.mode);
    await user.selectOptions(select, strings.config.commissionModes.flat);

    expect(onChange).toHaveBeenCalledTimes(1);
    expect(onChange).toHaveBeenCalledWith('flat');
  });

  it('starts from flat mode and switches back to percent', async () => {
    const user = userEvent.setup();
    const onChange = vi.fn();
    render(<CommissionModeSelect mode="flat" onChange={onChange} />);

    const select = screen.getByLabelText(strings.config.fields.mode) as HTMLSelectElement;
    expect(select.value).toBe('flat');

    await user.selectOptions(select, strings.config.commissionModes.percent);
    expect(onChange).toHaveBeenCalledWith('percent');
  });
});
