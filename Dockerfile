
FROM intersystemsdc/iris-community

USER root
RUN apt update && apt-get -y install git && apt-get -y install telnet

WORKDIR /opt/irisbuild
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild

ENV IRISUSERNAME "SuperUser"
ENV IRISPASSWORD "SYS"
ENV IRISNAMESPACE "%SYS"

ENV PIP_TARGET=${ISC_PACKAGE_INSTALLDIR}/mgr/python
ENV PYTHON_PATH=/usr/irissys/bin/
ENV LD_LIBRARY_PATH=${ISC_PACKAGE_INSTALLDIR}/bin:${LD_LIBRARY_PATH}
ENV PATH "/home/irisowner/.local/bin:/usr/irissys/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/irisowner/bin"

# Remove EXTERNAL-MANAGER from the system
RUN rm -f /usr/lib/python3.12/EXTERNALLY-MANAGED

USER ${ISC_PACKAGE_MGRUSER}

COPY src src
COPY module.xml module.xml
COPY iris.script iris.script
COPY requirements.txt requirements.txt
COPY movie_dataset.csv movie_dataset.csv

RUN pip3 install -r requirements.txt

EXPOSE 52773

RUN iris start IRIS \
	&& iris session IRIS < iris.script \
    && iris stop IRIS quietly

