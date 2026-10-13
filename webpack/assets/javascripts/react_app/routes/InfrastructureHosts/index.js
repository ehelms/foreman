import React from 'react';
import InfrastructureHostsPage from './InfrastructureHostsPage';
import InfrastructureHostDetailsPage from './InfrastructureHostDetailsPage';
import { INFRASTRUCTURE_HOSTS_PATH } from './constants';

export default [
  {
    path: INFRASTRUCTURE_HOSTS_PATH,
    render: props => <InfrastructureHostsPage {...props} />,
    exact: true,
  },
  {
    path: `${INFRASTRUCTURE_HOSTS_PATH}/:id`,
    render: props => <InfrastructureHostDetailsPage {...props} />,
    exact: true,
  },
];
