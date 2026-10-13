import React from 'react';
import { createMemoryHistory } from 'history';
import { Router } from 'react-router-dom';
import { fireEvent, screen } from '@testing-library/react';
import '@testing-library/jest-dom';

import { rtlHelpers } from '../../common/rtlTestHelpers';
import { STATUS } from '../../constants';
import { useAPI } from '../../common/hooks/API/APIHooks';
import InfrastructureHostsPage from './InfrastructureHostsPage';

jest.mock('../../common/hooks/API/APIHooks', () => ({
  useAPI: jest.fn(),
}));

const { renderWithStoreAndI18n } = rtlHelpers;

const renderPage = (response, status = STATUS.RESOLVED) => {
  const history = createMemoryHistory({
    initialEntries: ['/infrastructure_hosts'],
  });
  useAPI.mockReturnValue({ response, status });
  const renderResult = renderWithStoreAndI18n(
    <Router history={history}>
      <InfrastructureHostsPage />
    </Router>
  );
  return { ...renderResult, history };
};

describe('InfrastructureHostsPage', () => {
  beforeEach(() => {
    window.URL_PREFIX = '';
    useAPI.mockReset();
  });

  it('renders Foreman and Capsule rows with proxy counts and navigates to details', () => {
    const { history } = renderPage({
      results: [
        {
          id: 'foreman.example.com',
          hostname: 'foreman.example.com',
          kind: 'foreman',
          smart_proxies_count: 1,
        },
        {
          id: 'capsule.example.com',
          hostname: 'capsule.example.com',
          kind: 'capsule',
          smart_proxies_count: 2,
        },
      ],
    });

    expect(screen.getByRole('table')).toHaveAccessibleName(
      'Foreman and Capsule hosts'
    );
    expect(
      screen.getByRole('columnheader', { name: 'Hostname' })
    ).toBeInTheDocument();
    expect(screen.getByText('Foreman')).toBeInTheDocument();
    expect(screen.getByText('Capsule')).toBeInTheDocument();
    expect(screen.getByText('1')).toBeInTheDocument();
    expect(screen.getByText('2')).toBeInTheDocument();

    const detailsLink = screen.getByRole('link', {
      name: 'capsule.example.com',
    });
    fireEvent.click(detailsLink);
    expect(history.location.pathname).toBe(
      '/infrastructure_hosts/capsule.example.com'
    );
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('renders an empty state when the inventory has no hosts', () => {
    renderPage({ results: [] });

    expect(
      screen.getByText('No Foreman or Capsule hosts are in the inventory.')
    ).toBeInTheDocument();
  });

  it('renders an API error state', () => {
    renderPage(
      {
        response: { data: { error: { message: 'inventory unavailable' } } },
      },
      STATUS.ERROR
    );

    expect(screen.getByText('inventory unavailable')).toBeInTheDocument();
  });

  it('renders a loading state', () => {
    renderPage({}, STATUS.PENDING);

    expect(screen.getByLabelText('Loading Page')).toBeInTheDocument();
  });
});
