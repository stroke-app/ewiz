import { queryOptions } from "@tanstack/react-query";

import { $getLicense } from "./functions";

export const licenseQueryOptions = () =>
  queryOptions({
    queryKey: ["license"],
    queryFn: ({ signal }) => $getLicense({ signal }),
  });
