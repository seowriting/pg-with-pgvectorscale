FROM rust:1.80.1-bullseye AS builder

SHELL ["/bin/bash", "-c"]

RUN apt update && apt -y install wget gnupg2
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ bullseye-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list
RUN apt update
RUN apt -y upgrade
RUN apt -y install pkg-config libpq-dev libssl-dev ca-certificates git libclang-dev postgresql-server-dev-16 postgresql-16 make

RUN rustup component add rustfmt
RUN cargo install cargo-pgrx --version 0.11.4 --locked
RUN cargo pgrx init --pg16 pg_config

RUN cd /tmp && git clone https://github.com/timescale/pgvectorscale && cd pgvectorscale/pgvectorscale && git checkout 0.3.0 && RUSTFLAGS="-C target-feature=+avx2,+fma" cargo pgrx package
RUN cd /tmp && git clone --branch v0.7.4 https://github.com/pgvector/pgvector && cd pgvector && make

FROM postgres:16.4-bullseye

RUN mkdir -p /usr/local/lib/postgresql/
RUN mkdir -p /usr/local/share/postgresql/extension/

COPY --from=builder /tmp/pgvector/vector.so /usr/lib/postgresql/16/lib/
COPY --from=builder /tmp/pgvector/vector.control /usr/share/postgresql/16/extension/
COPY --from=builder /tmp/pgvector/sql/*.sql /usr/share/postgresql/16/extension/
COPY --from=builder /tmp/pgvectorscale/pgvectorscale/target/release/vectorscale-pg16/usr/lib/postgresql/16/lib/vectorscale-0.3.0.so /usr/lib/postgresql/16/lib/
COPY --from=builder /tmp/pgvectorscale/pgvectorscale/target/release/vectorscale-pg16/usr/share/postgresql/16/extension/*.* /usr/share/postgresql/16/extension/

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
