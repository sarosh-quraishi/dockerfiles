FROM tensorflow/tensorflow:latest-devel

##ngraph-part:

RUN apt-get update && apt-get install -y \
        build-essential cmake \
        clang-3.9 clang-format-3.9 \
        git \
        wget patch diffutils zlib1g-dev libtinfo-dev \
        doxygen graphviz \
        python-pip

RUN apt-get clean autoclean && \
    apt-get autoremove -y
RUN pip install --upgrade pip

# need to use sphinx version 1.6 to build docs
# installing with apt-get install python-sphinx installs sphinx version 1.3.6 only
# added install for python-pip above and
# installed sphinx with pip to get the updated version 1.6.5
# allows for make html build under the doc/source directory as an interim build process
RUN pip install sphinx
RUN pip install breathe

# need numpy to successfully build docs for python_api
RUN pip install numpy

# Download and build ngraph
WORKDIR /
RUN rm -rf ngraph && \
  git clone https://github.com/NervanaSystems/ngraph.git && \
  cd ngraph && \
  mkdir build && \
  cd build && \
#  cmake ../ -DNGRAPH_USE_PREBUILT_LLVM=TRUE -DNGRAPH_TARGET_ARCH=skylake-avx512 && \
  cmake ../ -DNGRAPH_USE_PREBUILT_LLVM=TRUE && \
  make -j4 && \
  make install
WORKDIR /ngraph
##end of ngraph-part



WORKDIR /
RUN rm -rf ngraph-tensorflow && \
  git clone https://github.com/NervanaSystems/ngraph-tensorflow.git && \
  cd ngraph-tensorflow && \
  git checkout ngraph-tensorflow-preview-0
WORKDIR /ngraph-tensorflow

# Configure the build for CPU with MKL by accepting default build options and
# setting library locations
ENV CI_BUILD_PYTHON=python \
   LD_LIBRARY_PATH=${LD_LIBRARY_PATH} \
    PYTHON_BIN_PATH=/usr/bin/python \
    PYTHON_LIB_PATH=/usr/local/lib/python2.7/dist-packages \
    CC_OPT_FLAGS='-march=native' \
    TF_NEED_JEMALLOC=0 \
    TF_NEED_GCP=0 \
    TF_NEED_CUDA=0 \
    TF_NEED_HDFS=0 \
    TF_NEED_S3=1 \
    TF_NEED_OPENCL=0 \
    TF_NEED_GDR=0 \
    TF_ENABLE_XLA=1 \
    TF_NEED_VERBS=0 \
    TF_NEED_MPI=0
RUN ./configure

RUN bazel build --config=opt //tensorflow/tools/pip_package:build_pip_package && \
  bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg

RUN pip install -U /tmp/tensorflow_pkg/*.whl

RUN cd .. && \
  git clone https://github.com/NervanaSystems/ngraph-tensorflow-bridge.git && \
  cd ngraph-tensorflow-bridge && \
  mkdir build && \
  cd build && \
  cmake ../ && \
  make install && \
  cd ../test && \
  python install_test.py && \
  pip install keras
