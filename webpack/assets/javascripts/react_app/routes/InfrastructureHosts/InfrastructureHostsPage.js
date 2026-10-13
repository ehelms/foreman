import React from 'react';
import { Link } from 'react-router-dom';
import { Table, Thead, Tbody, Tr, Th, Td } from '@patternfly/react-table';

import { translate as __ } from '../../common/I18n';
import { useAPI } from '../../common/hooks/API/APIHooks';
import { STATUS } from '../../constants';
import EmptyPage from '../common/EmptyPage';
import LoadingPage from '../common/LoadingPage';
import PageLayout from '../common/PageLayout/PageLayout';
import {
  INFRASTRUCTURE_HOSTS_PATH,
  INFRASTRUCTURE_HOSTS_API_PATH,
} from './constants';

const InfrastructureHostsPage = () => {
  const { response = {}, status = STATUS.PENDING } = useAPI(
    'get',
    `${INFRASTRUCTURE_HOSTS_API_PATH}?per_page=all`,
    { key: 'INFRASTRUCTURE_HOSTS' }
  );
  const hosts = response.results || [];
  const hostnameLabel = __('Hostname');
  const typeLabel = __('Type');
  const proxiesLabel = __('Smart proxies');

  let content;
  if (status === STATUS.ERROR) {
    content = (
      <EmptyPage
        message={{
          type: 'error',
          text:
            response.response?.data?.error?.message ||
            __('Unable to load the infrastructure host inventory.'),
        }}
      />
    );
  } else if (status !== STATUS.RESOLVED) {
    content = <LoadingPage />;
  } else if (hosts.length === 0) {
    content = (
      <EmptyPage
        message={{
          type: 'empty',
          text: __('No Foreman or Capsule hosts are in the inventory.'),
        }}
      />
    );
  } else {
    content = (
      <Table
        aria-label={__('Foreman and Capsule hosts')}
        variant="compact"
        ouiaId="infrastructure-hosts-table"
      >
        <Thead>
          <Tr>
            <Th>{hostnameLabel}</Th>
            <Th>{typeLabel}</Th>
            <Th>{proxiesLabel}</Th>
          </Tr>
        </Thead>
        <Tbody>
          {hosts.map(host => (
            <Tr key={host.id}>
              <Td dataLabel={hostnameLabel}>
                <Link
                  to={`${INFRASTRUCTURE_HOSTS_PATH}/${encodeURIComponent(
                    host.hostname
                  )}`}
                >
                  {host.hostname}
                </Link>
              </Td>
              <Td dataLabel={typeLabel}>
                {host.kind === 'foreman' ? __('Foreman') : __('Capsule')}
              </Td>
              <Td dataLabel={proxiesLabel}>{host.smart_proxies_count}</Td>
            </Tr>
          ))}
        </Tbody>
      </Table>
    );
  }

  return (
    <PageLayout header={__('Foreman and Capsules')} searchable={false}>
      {content}
    </PageLayout>
  );
};

export default InfrastructureHostsPage;
