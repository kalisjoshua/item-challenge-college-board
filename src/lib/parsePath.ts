type ResultValid = [{ parameter?: string; path: string; root: boolean }, false];
type ResultInvalid = [{ path: null; root: false }, Error];

export function parsePath(path: string): ResultValid | ResultInvalid {
  let wip = path
    .replace(/^\/api/, "")
    .split("/")
    .filter(Boolean);

  switch (wip.length) {
    case 0:
      return [{ path: "/", root: true }, false];
    case 1:
      return [{ path: `/${wip[0]}`, root: false }, false];
    case 2:
      return [{ parameter: wip[1], path: `/${wip[0]}`, root: false }, false];
    default:
      return [{ path: null, root: false }, new Error(`Invalid path: ${path}`)];
  }
}
