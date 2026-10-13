import React from 'react';
import { createMemoryHistory } from 'history';
import { Router } from 'react-router-dom';
import { screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Immutable from 'seamless-immutable';

import { rtlHelpers } from '../../common/rtlTestHelpers';
import { STATUS } from '../../constants';
import { useAPI } from '../../common/hooks/API/APIHooks';
import InfrastructureHostDetailsPage from './InfrastructureHostDetailsPage';

jest.mock('../../common/hooks/API/APIHooks', () => ({
  useAPI: jest.fn(),
}));

const { renderWithStoreAndI18n } = rtlHelpers;

const renderPage = (
  response,
  status = STATUS.RESOLVED,
  id = 'capsule.example.com',
  proxyDetails = {},
  proxyPings = {}
) => {
  const history = createMemoryHistory({
    initialEntries: [`/infrastructure_hosts/${encodeURIComponent(id)}`],
  });
  useAPI.mockImplementation((_method, url) => {
    if (typeof url !== 'string')
      return { response: {}, status: STATUS.RESOLVED };

    const detailsMatch = url.match(/\/api\/v2\/smart_proxies\/(\d+)/);
    if (detailsMatch) {
      const details = proxyDetails[detailsMatch[1]];
      return details || { response: {}, status: STATUS.PENDING };
    }

    const pingMatch = url.match(/\/smart_proxies\/(\d+)\/ping/);
    if (pingMatch) {
      const ping = proxyPings[pingMatch[1]];
      return ping || { response: {}, status: STATUS.PENDING };
    }

    return { response, status };
  });
  const renderResult = renderWithStoreAndI18n(
    <Router history={history}>
      <InfrastructureHostDetailsPage match={{ params: { id } }} />
    </Router>
  );
  return { ...renderResult, history };
};

describe('InfrastructureHostDetailsPage', () => {
  beforeEach(() => {
    window.URL_PREFIX = '';
    useAPI.mockReset();
  });

  it('renders host details and smart proxy overview information', async () => {
    renderPage(
      {
        hostname: 'capsule.example.com',
        kind: 'capsule',
        smart_proxies: [
          {
            id: 7,
            name: 'Capsule Proxy',
            url: 'https://capsule.example.com:8443',
          },
        ],
      },
      STATUS.RESOLVED,
      'capsule.example.com',
      {
        7: {
          response: {
            features: Immutable([{ name: 'DHCP' }, { name: 'DNS' }]),
            unrecognized_features: Immutable(['Custom feature']),
            hosts_count: 5,
          },
          status: STATUS.RESOLVED,
        },
      },
      {
        7: {
          response: { success: true, message: { version: '4.14.0' } },
          status: STATUS.RESOLVED,
        },
      }
    );

    expect(
      await screen.findByRole('heading', { name: 'capsule.example.com' })
    ).toBeInTheDocument();
    expect(screen.getByText('Capsule')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Capsule Proxy' })).toHaveAttribute(
      'href',
      '/smart_proxies/7'
    );
    expect(
      screen.getByText('https://capsule.example.com:8443')
    ).toBeInTheDocument();
    expect(
      screen.getByRole('columnheader', { name: 'Communication status' })
    ).toBeInTheDocument();
    expect(screen.getByText('Active')).toBeInTheDocument();
    expect(screen.getByText('4.14.0')).toBeInTheDocument();
    expect(screen.getByText('DHCP, DNS')).toBeInTheDocument();
    expect(screen.getByText('Custom feature')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: '5' })).toHaveAttribute(
      'href',
      '/hosts?search=smart_proxy%20%3D%20%22Capsule%20Proxy%22'
    );
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });

  it('renders a zero-proxy state for a Foreman host', async () => {
    renderPage(
      {
        hostname: 'foreman.example.com',
        kind: 'foreman',
        smart_proxies: [],
      },
      STATUS.RESOLVED,
      'foreman.example.com'
    );

    expect(await screen.findByText('Foreman')).toBeInTheDocument();
    expect(
      await screen.findByText('No smart proxies are registered on this host.')
    ).toBeInTheDocument();
  });

  it('renders API error and loading states', async () => {
    renderPage(
      { response: { data: { error: { message: 'host not found' } } } },
      STATUS.ERROR
    );
    expect(await screen.findByText('host not found')).toBeInTheDocument();

    renderPage({}, STATUS.PENDING);
    expect(await screen.findByLabelText('Loading Page')).toBeInTheDocument();
  });
});
