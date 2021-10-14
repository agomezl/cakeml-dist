########
# Core #
########
FROM trustworthysystems/camkes as core

# Install dependencies and setup users
RUN apt-get update

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

##########
# CakeML #
##########
FROM cakeml as choreo

COPY ${ENV_REPO_LOCATION}/choreo /opt/choreo

FROM trustworthysystems/camkes

# arguments
ARG HOME=/home/cake

# Setup
RUN apt-get update && \
    apt-get install -y sudo emacs && \
    groupadd wheel && \
    useradd -ms /bin/bash cake && \
    echo "cake:docker" | chpasswd && \
    usermod -a -G wheel cake && \
    echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

USER cake
WORKDIR ${HOME}

COPY --from=cakeml /opt/polyml /opt/polyml
COPY --from=cakeml --chown=cake /opt/HOL /opt/HOL/
COPY --from=cakeml --chown=cake /opt/cakeml ${HOME}/cakeml/
COPY --from=choreo --chown=cake /opt/choreo ${HOME}/choreo/
COPY --chown=cake ${ENV_REPO_LOCATION}/cake-x64-64  /opt/cake

ENV PATH /opt/polyml/bin/:${PATH}
ENV PATH /opt/HOL/bin/:${PATH}
ENV PATH /opt/cake:${PATH}
ENV LANG en_US.UTF-8

# HOL Stuff
RUN cd choreo/projection/proofs/to_cake && Holmake && \
    cd && cd choreo/examples/filter && Holmake && \
    echo '(load "/opt/HOL/tools/hol-mode")' >> ~/.emacs && \
    echo '(load "/opt/HOL/tools/hol-unicode")' >> ~/.emacs && \
    echo '(transient-mark-mode 1)' >> ~/.emacs && \
    cd /opt/cake && make && cd && \
    git config --global user.email "cake@cakeml.org" && \
    git config --global user.name "Mr Cake" && \
    git config --global color.ui  auto

# Camkes Stuff
RUN mkdir camkes-sel4 && cd camkes-sel4 && \
    repo init -u https://github.com/seL4/camkes-manifest && \
    repo sync && cd && \
    ln -s ${HOME}/choreo/examples/filter/filter_camkes \
          ${HOME}/camkes-sel4/projects/camkes/apps/ && \
    cd camkes-sel4 && mkdir build-filter && cd build-filter && \
    ../init-build.sh -DPLATFORM=x86_64 -DCAMKES_APP=filter_camkes && \
    ninja

CMD emacs choreo/
