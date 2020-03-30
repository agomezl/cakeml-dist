########
# Core #
########
FROM fedora:30 as core

# Arguments
ARG HOME
ENV HOME=${HOME:-/home/cake}

# Install dependencies and setup users
RUN dnf -y group install 'Development Tools' && \
    dnf -y install gcc-c++ git sudo wget libffi-devel libtool && \
    useradd -ms /bin/bash cake && \
    echo "cake:docker" | chpasswd && \
    usermod -a -G wheel cake && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER cake

WORKDIR ${HOME}

##########
# PolyML #
##########
FROM core as poly

# Arguments
ARG ENV_REPO_LOCATION
ENV ENV_REPO_LOCATION=${ENV_REPO_LOCATION:-.}
ARG POLYML_DIR
ENV POLYML_DIR=${POLYML_DIR:-${HOME}/opt/polyml}

# Copy polyml repo from the local context
COPY --chown=cake ${ENV_REPO_LOCATION}/polyml ${HOME}/polyml/

# Build polyml
RUN cd polyml && \
    ./configure --prefix=${POLYML_DIR} && \
     make && make compiler && make install

########
# HOL4 #
########
FROM poly as hol

# Where to find polyml
ENV PATH ${POLYML_DIR}/bin/:${PATH}

# Copy HOL4 repo from the local context
COPY --chown=cake ${ENV_REPO_LOCATION}/HOL ${HOME}/HOL/

# Build HOL4
RUN cd HOL && \
    poly < tools/smart-configure.sml && \
    bin/build

##########
# CakeML #
##########
FROM hol as cakeml

# Where to find HOL4
ENV PATH ${HOME}/HOL/bin/:${PATH}
ENV HOLDIR ${HOME}/HOL

COPY --chown=cake ${ENV_REPO_LOCATION}/cakeml ${HOME}/cakeml/

# Build CakeML
RUN cd cakeml/ && \
    for dir in $(cat developers/build-sequence | grep -Ev '^([ #]|$)'); \
    do cd ${dir} && Holmake && cd -; \
    done


FROM fedora:30

# arguments
ARG HOME=/home/cake
ARG POLYML_DIR=${HOME}/opt/polyml

RUN dnf -y install git sudo

# Add user
RUN useradd -ms /bin/bash cake && \
    echo "cake:docker" | chpasswd && \
    usermod -a -G wheel cake && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER cake
WORKDIR ${HOME}

RUN mkdir -p ${POLYML_DIR} ${HOME}/HOL ${HOME}/cakeml
COPY --from=cakeml --chown=cake ${POLYML_DIR} ${POLYML_DIR}/
ENV PATH ${POLYML_DIR}/bin/:${PATH}
COPY --from=cakeml --chown=cake ${HOME}/HOL ${HOME}/HOL/
ENV PATH ${HOME}/HOL/bin/:${PATH}
COPY --from=cakeml --chown=cake ${HOME}/cakeml ${HOME}/cakeml/
