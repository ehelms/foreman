FROM centos:7

RUN yum -y install epel-release
RUN yum -y install npm nodejs git ruby rubygem-bundler bzip2

WORKDIR /root
COPY build-webpack /root/build-webpack

RUN git clone https://github.com/theforeman/foreman
RUN cd foreman && npm install

CMD ["./build-webpack"]
