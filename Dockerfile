########
# Core #
########
FROM fedora:34 as core

# Install dependencies and setup users
RUN dnf -y group install 'Development Tools' && \
    dnf -y install gcc-c++ git sudo wget libffi-devel libtool

##########
# PolyML #
##########
FROM core as poly

# Arguments
ARG ENV_REPO_LOCATION
ENV ENV_REPO_LOCATION=${ENV_REPO_LOCATION:-.}

# Copy polyml repo from the local context
COPY ${ENV_REPO_LOCATION}/polyml /opt/polyml/

# Build polyml
RUN cd /opt/polyml && \
    ./configure --prefix=/opt/polyml && \
     make && make compiler && make install

# Where to find polyml
ENV PATH /opt/polyml/bin/:${PATH}

########
# HOL4 #
########
FROM poly as hol

# Copy HOL4 repo from the local context
COPY ${ENV_REPO_LOCATION}/HOL /opt/HOL/

# Build HOL4
RUN cd /opt/HOL && \
    poly < tools/smart-configure.sml && \
    bin/build

# Where to find Holmake
ENV PATH /opt/HOL/bin/:${PATH}

##########
# CakeML #
##########
FROM hol as cakeml

ENV HOLDIR /opt/HOL

COPY ${ENV_REPO_LOCATION}/cakeml /opt/cakeml/

# Build CakeML
# RUN cd /opt/cakeml/ && \
#     for dir in $(cat developers/build-sequence | grep -Ev '^([ #]|$)'); \
#     do cd ${dir} && Holmake && cd -; \
#     done

FROM fedora:30

# arguments
ARG HOME=/home/cake

# Setup
RUN dnf -y install git sudo gcc-c++ && \
    useradd -ms /bin/bash cake && \
    echo "cake:docker" | chpasswd && \
    usermod -a -G wheel cake && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER cake
WORKDIR ${HOME}

COPY --from=cakeml /opt/polyml /opt/polyml
ENV PATH /opt/polyml/bin/:${PATH}
COPY --from=cakeml --chown=cake /opt/HOL /opt/HOL/
ENV PATH /opt/HOL/bin/:${PATH}
COPY --from=cakeml --chown=cake /opt/cakeml ${HOME}/cakeml/
