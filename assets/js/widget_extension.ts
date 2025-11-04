// this url gets automatically hydrated by the build system
// Usage example, if undefined use a default:
//     const origin = typeof PHOENIX_STARTER_KIT_API_ORIGIN !== 'undefined' ? PHOENIX_STARTER_KIT_API_ORIGIN : 'https://phoenix_starter_kit.peeklabs.com';
//    const url = `${origin}/widget/..../status`;
declare const PHOENIX_STARTER_KIT_API_ORIGIN: string;

export default async function (this: {
  subscribeToAppEvent: (
    eventName: string,
    handler: (event: { data: { value: any } }) => void,
  ) => void;
  callPeekExtensionsAPI: (method: string, serviceName: string) => any;
  config: { accessToken: string };
}) {
  // Add your widget extension code here
}
