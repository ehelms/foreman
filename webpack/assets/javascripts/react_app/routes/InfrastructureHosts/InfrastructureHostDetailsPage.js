import React from 'react';
import PropTypes from 'prop-types';
import { useHistory } from 'react-router-dom';
import {
  Card,
  CardBody,
  CardTitle,
  DescriptionList,
  DescriptionListDescription,
  DescriptionListGroup,
  DescriptionListTerm,
} from '@patternfly/react-core';
import { Table, Thead, Tbody, Tr, Th, Td } from '@patternfly/react-table';

import { translate as __ } from '../../common/I18n';
import { foremanUrl } from '../../common/helpers';
import { useAPI } from '../../common/hooks/API/APIHooks';
import { STATUS } from '../../constants';
import EmptyPage from '../common/EmptyPage';
import LoadingPage from '../common/LoadingPage';
import PageLayout from '../common/PageLayout/PageLayout';
import {
  INFRASTRUCTURE_HOSTS_PATH,
  INFRASTRUCTURE_HOSTS_API_PATH,
} from './constants';

const SmartProxyRow = ({ proxy }) => {
  const proxyDetailsUrl = foremanUrl(`/api/v2/smart_proxies/${proxy.id}`);
  const proxyPingUrl = foremanUrl(`/smart_proxies/${proxy.id}/ping`);
  const {
    response: proxyDetails = {},
    status: detailsStatus = STATUS.PENDING,
  } = useAPI('get', proxyDetailsUrl, {
    key: `INFRASTRUCTURE_SMART_PROXY_${proxy.id}`,
  });
  const {
    response: pingResponse = {},
    status: pingStatus = STATUS.PENDING,
  } = useAPI('get', proxyPingUrl, {
    key: `INFRASTRUCTURE_SMART_PROXY_PING_${proxy.id}`,
  });

  const detailsLoading = detailsStatus === STATUS.PENDING;
  const detailsUnavailable = detailsStatus === STATUS.ERROR;
  const pingLoading = pingStatus === STATUS.PENDING;
  const activeFeatures = Array.from(
    proxyDetails.features || [],
    feature => feature.name
  ).sort();
  const unrecognizedFeatures = proxyDetails.unrecognized_features || [];
  const version = pingResponse.message?.version || __('Unknown');
  const hostsUrl = foremanUrl(
    `/hosts?search=${encodeURIComponent(`smart_proxy = "${proxy.name}"`)}`
  );
  const nameLabel = __('Name');
  const statusLabel = __('Communication status');
  const urlLabel = __('URL');
  const versionLabel = __('Version');
  const featuresLabel = __('Active features');
  const unrecognizedFeaturesLabel = __('Unrecognized features');
  const hostsLabel = __('Hosts managed');

  return (
    <Tr>
      <Td dataLabel={nameLabel}>
        <a href={foremanUrl(`/smart_proxies/${proxy.id}`)}>{proxy.name}</a>
      </Td>
      <Td dataLabel={statusLabel}>
        {pingLoading
          ? __('Loading...')
          : pingResponse.success
          ? __('Active')
          : __('Failed')}
      </Td>
      <Td dataLabel={urlLabel}>{proxy.url}</Td>
      <Td dataLabel={versionLabel}>
        {pingLoading
          ? __('Loading...')
          : pingResponse.success
          ? version
          : __('Unavailable')}
      </Td>
      <Td dataLabel={featuresLabel}>
        {detailsLoading
          ? __('Loading...')
          : detailsUnavailable
          ? __('Unavailable')
          : activeFeatures.join(', ') || '—'}
      </Td>
      <Td dataLabel={unrecognizedFeaturesLabel}>
        {detailsLoading
          ? __('Loading...')
          : detailsUnavailable
          ? __('Unavailable')
          : unrecognizedFeatures.join(', ') || '—'}
      </Td>
      <Td dataLabel={hostsLabel}>
        {detailsLoading ? (
          __('Loading...')
        ) : detailsUnavailable ? (
          __('Unavailable')
        ) : (
          <a href={hostsUrl}>{proxyDetails.hosts_count}</a>
        )}
      </Td>
    </Tr>
  );
};

SmartProxyRow.propTypes = {
  proxy: PropTypes.shape({
    id: PropTypes.number.isRequired,
    name: PropTypes.string.isRequired,
    url: PropTypes.string.isRequired,
  }).isRequired,
};

const InfrastructureHostDetailsPage = ({
  match: {
    params: { id },
  },
}) => {
  const history = useHistory();
  const { response, status } = useAPI(
    'get',
    `${INFRASTRUCTURE_HOSTS_API_PATH}/${encodeURIComponent(id)}`,
    { key: `INFRASTRUCTURE_HOST_${id}` }
  );
  const hostname = response.hostname || id;
  const breadcrumbOptions = {
    breadcrumbItems: [
      {
        caption: __('Foreman and Capsules'),
        url: INFRASTRUCTURE_HOSTS_PATH,
        onClick: event => {
          event.preventDefault();
          history.push(INFRASTRUCTURE_HOSTS_PATH);
        },
      },
      { caption: hostname },
    ],
  };

  let content;
  if (status === STATUS.ERROR) {
    content = (
      <EmptyPage
        message={{
          type: 'error',
          text:
            response.response?.data?.error?.message ||
            __('Unable to load infrastructure host.'),
        }}
      />
    );
  } else if (status !== STATUS.RESOLVED) {
    content = <LoadingPage />;
  } else {
    const proxies = response.smart_proxies || [];
    content = (
      <>
        <DescriptionList isHorizontal>
          <DescriptionListGroup>
            <DescriptionListTerm>{__('Hostname')}</DescriptionListTerm>
            <DescriptionListDescription>{hostname}</DescriptionListDescription>
          </DescriptionListGroup>
          <DescriptionListGroup>
            <DescriptionListTerm>{__('Type')}</DescriptionListTerm>
            <DescriptionListDescription>
              {response.kind === 'foreman' ? __('Foreman') : __('Capsule')}
            </DescriptionListDescription>
          </DescriptionListGroup>
        </DescriptionList>
        <Card>
          <CardTitle>{__('Smart proxies')}</CardTitle>
          <CardBody>
            {proxies.length === 0 ? (
              <EmptyPage
                message={{
                  type: 'empty',
                  text: __('No smart proxies are registered on this host.'),
                }}
              />
            ) : (
              <Table
                aria-label={__('Registered Smart Proxies')}
                variant="compact"
                ouiaId="infrastructure-host-proxies-table"
              >
                <Thead>
                  <Tr>
                    <Th>{__('Name')}</Th>
                    <Th>{__('Communication status')}</Th>
                    <Th>{__('URL')}</Th>
                    <Th>{__('Version')}</Th>
                    <Th>{__('Active features')}</Th>
                    <Th>{__('Unrecognized features')}</Th>
                    <Th>{__('Hosts managed')}</Th>
                  </Tr>
                </Thead>
                <Tbody>
                  {proxies.map(proxy => (
                    <SmartProxyRow key={proxy.id} proxy={proxy} />
                  ))}
                </Tbody>
              </Table>
            )}
          </CardBody>
        </Card>
      </>
    );
  }

  return (
    <PageLayout
      header={hostname}
      breadcrumbOptions={breadcrumbOptions}
      searchable={false}
    >
      {content}
    </PageLayout>
  );
};

InfrastructureHostDetailsPage.propTypes = {
  match: PropTypes.shape({
    params: PropTypes.shape({
      id: PropTypes.string.isRequired,
    }).isRequired,
  }).isRequired,
};

export default InfrastructureHostDetailsPage;
