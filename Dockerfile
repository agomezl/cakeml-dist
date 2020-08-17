########
# Core #
########
FROM fedora:32 as core

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
COPY ${ENV_REPO_LOCATION}/HOL /home/cake/HOL/

# Build HOL4
RUN cd /home/cake/HOL && \
    poly < tools/smart-configure.sml && \
    bin/build

# Where to find Holmake
ENV PATH /home/cake/HOL/bin/:${PATH}

##########
# CakeML #
##########

FROM fedora:32

# arguments
ARG HOME=/home/cake

# Setup
RUN dnf -y install git sudo gcc-c++ emacs && \
    useradd -ms /bin/bash cake && \
    echo "cake:docker" | chpasswd && \
    usermod -a -G wheel cake && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER cake
WORKDIR ${HOME}

COPY --from=hol /opt/polyml /opt/polyml/
COPY --from=hol --chown=cake ${HOME}/HOL ${HOME}/HOL/
COPY --chown=cake ${ENV_REPO_LOCATION}/cakeml ${HOME}/cakeml/

ENV PATH /opt/polyml/bin/:${PATH}
ENV PATH ${HOME}/HOL/bin/:${PATH}
ENV LANG en_US.UTF-8

RUN cd ${HOME}/cakeml/examples/cost && Holmake && \
    cd ${HOME}/cakeml/compiler/proofs && Holmake && \
    echo '(load "/opt/HOL/tools/hol-mode")' >> ~/.emacs && \
    echo '(transient-mark-mode 1)' >> ~/.emacs

CMD emacs cakeml/
