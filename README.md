# docker-fritzbox-backup

## Introduction
This Docker application provides functionality to automatically download a configuration backup of an external `AVM FRITZ!Box` device to a file stored in a Docker volume, from where it can be backed up more easily using software like [Duplicati](https://github.com/duplicati/duplicati).

Backups will be created on a periodic basis configurable by editing the `CRON` environment variable.

The configuration will be encrypted with no password, a password of your choice or "admin" as a default. Keep in mind that you won't be able to load the config without the correct encryption password.

This project is based on the [original work of `the2masters`](https://github.com/the2masters/fritzbox-config-downloader).

## Quick Start
Example `docker-compose.yml`:

```yaml
version: "3"

volumes:
  fritzbox-backups:
    driver: local

services:
  fritzbox-backup:
    image: finnkrestel/docker-fritzbox-backup
    container_name: fritzbox-backup
    security_opt:
      - "no-new-privileges:true"
    volumes:
      - fritzbox-backups:/backups
    environment:
      - HOST=fritz.box
      - USERNAME=fritzXXXX
      - PASSWORD=password
      - EXPORT_PASSWORD=export_password
#      - EXPORT_FILENAME=FritzBox.export
#      - SECOND_PASSWORD=second_password
      - RETENTION_DAYS=14
      - CRON=0 4 * * *
```

## Configuration
| Environment variable              | Description              | Default   |
|:----------------------|:-------------------------|:----------|
| HOST | Hostname or IP of the FRITZ!Box to backup. Port is optional. | Default is `fritz.box`. |
| USERNAME | Username for newer versions of FRITZ!OS and for remote access. | Default is `no username`. |
| PASSWORD | Password for the FRITZ!Box. | Default is `no password`. |
| EXPORT_PASSWORD | Password for the backup file. | If present but no password set, the default is `admin`. |
| EXPORT_FILENAME | Output file to store the downloaded config. | Defaults to `FritzBox.export` |
| SECOND_PASSWORD | Older FRITZ!Box models secure remote access with HTTP-Auth. If the FRITZ!Box has a password for local access to the webinterface this password is needed, too. In this case, pass the remote access password as using the `PASSWORD` environment variable and the local webinterface password using this `SECOND_PASSWORD` environment variable. FRITZ!OS 5.50 fixes this Bug, it doesn't need this parameter anymore. So in most cases you won't need this argument. | Default is `no password`. |
| RETENTION_DAYS | Days to retain the exports for. Set to `-1` to disable. | Default is `14`. |
| CRON | Cron schedule for exporting. | Default is `0 4 * * *`. |

## Disclaimer
This project is not affiliated, associated, authorized, endorsed by, or in any way officially connected with AVM.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.