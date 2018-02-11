#ifndef _MAIN_H_
#define _MAIN_H_

void NodeService_onDrawFrame(float viewMatrixElements[], float projectionMatrixElements[], float centerArrayElements[]);
void NodeService_start(const char *binPathString, const char *jsPathString, const char *libPathString, const char *dataPathString, const char *urlString, const char *vrModeString, int vrTexture, int vrTexture2);
void NodeService_tick(int timeout);

#endif
