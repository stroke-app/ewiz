import { queryOptions } from "@tanstack/react-query";

import { $getLatestRelease, $getReleases } from "./functions";

export const releasesQueryOptions = () =>
  queryOptions({
    queryKey: ["releases"],
    queryFn: ({ signal }) => $getReleases({ signal }),
  });

export const latestReleaseQueryOptions = () =>
  queryOptions({
    queryKey: ["releases", "latest"],
    queryFn: ({ signal }) => $getLatestRelease({ signal }),
  });
