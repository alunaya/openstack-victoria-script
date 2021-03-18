# Table of contents
1. [Cấu hình controller node](#cấu-hình-controller-node)
2. [Cấu hình proxy server](#cấu-hình-proxy-server)
3. [Cấu hình storage server](#cấu-hình-storage-server)

# Cấu hình controller node
Cơ chế xác thực (authentication) và ủy quyền (authorization) của Swift thường dựa trên Keystone (Identity service). Tuy nhiên, không giống như các dịch vụ khác, nó cũng cung cấp một cơ chế nội bộ cho phép nó hoạt động mà không cần bất kỳ dịch vụ OpenStack nào khác. Trước khi cấu hình Swift, bạn phải tạo thông tin xác thực dịch vụ và API endpoint.

Guid này cho rằng bạn đang truy cập bằng người dùng **root**, nếu không bạn thêm **sudo** vào trước các lệnh

1. Chạy script để có quyền truy cập vào các lệnh CLI chỉ dành cho quản trị viên
```bash
$ . admin-openrc
```

2. Để tạo thông tin đăng nhập dịch vụ Identity, hãy hoàn thành các bước sau
    * tạo người dùng **swift**
    ```bash
        $ openstack user create --domain default --password-prompt swift
        User Password:
        Repeat User Password:
        +-----------+----------------------------------+
        | Field     | Value                            |
        +-----------+----------------------------------+
        | domain_id | default                          |
        | enabled   | True                             |
        | id        | d535e5cbd2b74ac7bfb97db9cced3ed6 |
        | name      | swift                            |
        +-----------+----------------------------------+
    ```
    
    * Thêm role **admin** cho người dùng **swift**:
    ```bash
    $ openstack role add --project service --user swift admin
    ```

    * Tạo **swift** service
    ```bash
        $ openstack service create --name swift \
        --description "OpenStack Object Storage" object-store
        +-------------+----------------------------------+
        | Field       | Value                            |
        +-------------+----------------------------------+
        | description | OpenStack Object Storage         |
        | enabled     | True                             |
        | id          | 75ef509da2c340499d454ae96a2c5c34 |
        | name        | swift                            |
        | type        | object-store                     |
        +-------------+----------------------------------+
    ```

3. Tạo Object Storage service API endpoints
    ```bash
    $ openstack endpoint create --region RegionOne \
    object-store public http://controller:8080/v1/AUTH_%\(project_id\)s
    +--------------+----------------------------------------------+
    | Field        | Value                                        |
    +--------------+----------------------------------------------+
    | enabled      | True                                         |
    | id           | 12bfd36f26694c97813f665707114e0d             |
    | interface    | public                                       |
    | region       | RegionOne                                    |
    | region_id    | RegionOne                                    |
    | service_id   | 75ef509da2c340499d454ae96a2c5c34             |
    | service_name | swift                                        |
    | service_type | object-store                                 |
    | url          | http://controller:8080/v1/AUTH_%(project_id)s |
    +--------------+----------------------------------------------+

    $ openstack endpoint create --region RegionOne \
    object-store internal http://controller:8080/v1/AUTH_%\(project_id\)s
    +--------------+----------------------------------------------+
    | Field        | Value                                        |
    +--------------+----------------------------------------------+
    | enabled      | True                                         |
    | id           | 7a36bee6733a4b5590d74d3080ee6789             |
    | interface    | internal                                     |
    | region       | RegionOne                                    |
    | region_id    | RegionOne                                    |
    | service_id   | 75ef509da2c340499d454ae96a2c5c34             |
    | service_name | swift                                        |
    | service_type | object-store                                 |
    | url          | http://controller:8080/v1/AUTH_%(project_id)s |
    +--------------+----------------------------------------------+

    $ openstack endpoint create --region RegionOne \
    object-store admin http://controller:8080/v1
    +--------------+----------------------------------+
    | Field        | Value                            |
    +--------------+----------------------------------+
    | enabled      | True                             |
    | id           | ebb72cd6851d4defabc0b9d71cdca69b |
    | interface    | admin                            |
    | region       | RegionOne                        |
    | region_id    | RegionOne                        |
    | service_id   | 75ef509da2c340499d454ae96a2c5c34 |
    | service_name | swift                            |
    | service_type | object-store                     |
    | url          | http://controller:8080/v1        |
    +--------------+----------------------------------+
    ```

# Cấu hình proxy server
1. Cài đặt python
    - Cập nhật các repo cài đặt
    ```bash
    apt update
    ```

    - Cài đặt gói phần mềm hỗ trợ thông dụng
    ```bash
    apt install software-properties-common
    ```

    - Thêm repo Deadsnakes
    ```bash
    add-apt-repository ppa:deadsnakes/ppa
    ```

    - Cập nhật lại repo cài đặt
    ```bash
    apt update
    ```

    - Cài đặt python phiên bản 3
    ```bash
    apt install python3
    ```

2. Cài đặt các packages cho swift
    ```bash
    apt-get install swift swift-proxy python3-swiftclient \
    python3-keystoneclient python3-keystonemiddleware \
    memcached
    ```

    - Tạo thư mục **/etc/swift**
        ```bash
        mkdir -p /etc/swift
        ```

    - Tải về file config mẫu cho proxy server
    ```bash
    curl -o /etc/swift/proxy-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/proxy-server.conf-sample
    ```

    - Chỉnh sửa file config **/etc/swift/proxy-server.conf** theo như dưới
        - Trong phần [DEFAULT], định cấu hình port, người dùng và thư mục cấu hình:
        ```txt
        [DEFAULT]
        ...
        bind_port = 8080
        user = swift
        swift_dir = /etc/swift
        ```

        - Trong phần [pipe: main], hãy xóa các mô-đun **tempurl** và **tempauth**, đồng thời thêm các mô-đun **authtoken** và **keystoneauth**
        ```txt
        [pipeline:main]
        pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server

        ```
        > **Note:**  
        > Đừng thay đổi thứ tự các mô đun.

        - Trong phần **[app: proxy-server]**, bật tạo tài khoản tự động:
        ```txt
        [app:proxy-server]
        use = egg:swift#proxy
        ...
        account_autocreate = True
        ```

        - Trong phần [filter: keystoneauth], cấu hình các vai trò của người quản trị:
        ```txt
        [filter:keystoneauth]
        use = egg:swift#keystoneauth
        ...
        operator_roles = admin,user
        ```

        - Trong phần [filter: authtoken], cấu hình quyền truy cập Identity service:
        ```txt
        [filter:authtoken]
        paste.filter_factory = keystonemiddleware.auth_token:filter_factory
        ...
        www_authenticate_uri = http://controller:5000
        auth_url = http://controller:5000
        memcached_servers = controller:11211
        auth_type = password
        project_domain_id = default
        user_domain_id = default
        project_name = service
        username = swift
        password = SWIFT_PASS
        delay_auth_decision = True
        ```
        Thay thế **SWIFT_PASS** bằng mật khẩu bạn đã chọn ở trên.

        - Trong phần [filter: cache], hãy định cấu hình vị trí memcached:
        ```txt
        [filter:cache]
        use = egg:swift#memcache
        ...
        memcache_servers = controller:11211
        ```

# Cấu hình storage server
## Cấu hình rsync

1. Cài đặt các gói tiện ích hỗ trợ
```bash
apt-get install xfsprogs rsync
```

2. Định dạng các thiết bị lưu trữ **/dev/sdb** và **/dev/sdc** thành XFS:
```bash
mkfs.xfs /dev/sdb
mkfs.xfs /dev/sdc
```

3. Tạo thư mục mount:
```bash
mkdir -p /srv/node/sdb
mkdir -p /srv/node/sdc
```

4. Tìm UUID các phân vùng vừa tạo:
```bash
blkid
```

5. sửa file **/etc/fstab** thêm các dòng dưới:
```txt
UUID="<UUID-from-output-above>" /srv/node/sdb xfs noatime 0 2
UUID="<UUID-from-output-above>" /srv/node/sdc xfs noatime 0 2
```

6. Mount các thiết bị:
```bash
mount /srv/node/sdb
mount /srv/node/sdc
```

7. Tạo hoặc chỉnh sửa tệp **/etc/rsyncd.conf** thêm các dòng sau:
```txt
    uid = swift
    gid = swift
    log file = /var/log/rsyncd.log
    pid file = /var/run/rsyncd.pid
    address = MANAGEMENT_INTERFACE_IP_ADDRESS

    [account]
    max connections = 2
    path = /srv/node/
    read only = False
    lock file = /var/lock/account.lock

    [container]
    max connections = 2
    path = /srv/node/
    read only = False
    lock file = /var/lock/container.lock

    [object]
    max connections = 2
    path = /srv/node/
    read only = False
    lock file = /var/lock/object.lock
```

Thay thế MANAGEMENT_INTERFACE_IP_ADDRESS bằng địa chỉ IP trên mạng quản lý.

8. Chỉnh sửa tệp **/etc/default/rsync** để bật dịch vụ rsync:
```txt
RSYNC_ENABLE=true
```

9. Khởi động dịch vụ rsync
```bash
service rsync start
```

## Cấu hình swift-storage
1. Cài đặt các package
```bash
apt-get install swift swift-account swift-container swift-object
```

2. Tải về các file cấu hình accounting, container và object service
```bash
curl -o /etc/swift/account-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/account-server.conf-sample
curl -o /etc/swift/container-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/container-server.conf-sample
curl -o /etc/swift/object-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/object-server.conf-sample
```

3. Chỉnh sửa tệp /etc/swift/account-server.conf
    - Trong phần [DEFAULT], cấu hình địa chỉ IP, port, người dùng, thư mục cấu hình và thư mục mountpoint
    ```txt
    [DEFAULT]
    ...
    bind_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
    bind_port = 6202
    user = swift
    swift_dir = /etc/swift
    devices = /srv/node
    mount_check = True
    ```
    Thay thế MANAGEMENT_INTERFACE_IP_ADDRESS bằng địa chỉ IP mạng quản lý.

    - Trong phần [pipeline:main], bật các mô-đun thích hợp
    ```txt
    [pipeline:main]
    pipeline = healthcheck recon account-server
    ```

    - Trong phần [filter:recon], cấu hình thư mục bộ nhớ cache của dịch vụ recon:
    ```txt
    [filter:recon]
    use = egg:swift#recon
    ...
    recon_cache_path = /var/cache/swift
    ```

4. Chỉnh sửa tệp **/etc/swift/container-server.conf**:
    - Trong phần [DEFAULT], cấu hình địa chỉ IP, cổng liên kết, người dùng, thư mục cấu hình và thư mục điểm gắn kết:
    ```txt
    [DEFAULT]
    ...
    bind_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
    bind_port = 6201
    user = swift
    swift_dir = /etc/swift
    devices = /srv/node
    mount_check = True
    ```
    Thay thế MANAGEMENT_INTERFACE_IP_ADDRESS bằng địa chỉ IP mạng quản lý.

    - Trong phần [pipeline:main], bật các mô-đun thích hợp:
    ```txt
    [pipeline:main]
    pipeline = healthcheck recon container-server
    ```

    - Trong phần [filter:recon], cấu hình thư mục bộ nhớ cache của dịch vụ recon:
    ```txt
    [filter:recon]
    use = egg:swift#recon
    ...
    recon_cache_path = /var/cache/swift
    ```

5. Chỉnh sửa tệp **/etc/swift/object-server.conf**:
    - Trong phần [DEFAULT], cấu hình địa chỉ IP, cổng liên kết, người dùng, thư mục cấu hình và thư mục điểm gắn kết:
    ```txt
    [DEFAULT]
    ...
    bind_ip = MANAGEMENT_INTERFACE_IP_ADDRESS
    bind_port = 6200
    user = swift
    swift_dir = /etc/swift
    devices = /srv/node
    mount_check = True
    ```
    Thay thế MANAGEMENT_INTERFACE_IP_ADDRESS bằng địa chỉ IP mạng quản lý.

    - Trong phần [pipeline:main], bật các mô-đun thích hợp:
    ```txt
    [pipeline:main]
    pipeline = healthcheck recon object-server
    ```

    - Trong phần [filter:recon], cấu hình thư mục bộ nhớ cache và khóa của dịch vụ recon:
    ```txt
    [filter:recon]
    use = egg:swift#recon
    ...
    recon_cache_path = /var/cache/swift
    recon_lock_path = /var/lock
    ...
    recon_cache_path = /var/cache/swift

6. Đảm bảo người dùng swift là chủ sở hữu cấu trúc thư mục mountpoint:
```bash
chown -R swift:swift /srv/node
```

7. Tạo thư mục recon và đảm bảo quyền sở hữu:
```bash
mkdir -p /var/cache/swift
chown -R root:swift /var/cache/swift
chmod -R 775 /var/cache/swift
```