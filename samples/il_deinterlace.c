//
// Update of il_render_video.c from Jan Newmarch with interlacing support
// via hardware advanced deinterlace. Changed to use mpeg2 because there 
// are not many interlaced x264 videos around
//

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#include <OMX_Core.h>
#include <OMX_Component.h>

#include <bcm_host.h>
#include <ilclient.h>

// #define IMG "/opt/vc/src/hello_pi/hello_video/test.h264"
char *IMG = "test.mpeg2video";

void printState(OMX_HANDLETYPE handle)
{
    OMX_STATETYPE state;
    OMX_ERRORTYPE err;

    err = OMX_GetState(handle, &state);
    if (err != OMX_ErrorNone)
    {
        fprintf(stderr, "Error on getting state\n");
        exit(1);
    }
    switch (state)
    {
    case OMX_StateLoaded:
        printf("StateLoaded\n");
        break;
    case OMX_StateIdle:
        printf("StateIdle\n");
        break;
    case OMX_StateExecuting:
        printf("StateExecuting\n");
        break;
    case OMX_StatePause:
        printf("StatePause\n");
        break;
    case OMX_StateWaitForResources:
        printf("StateWait\n");
        break;
    case OMX_StateInvalid:
        printf("StateInvalid\n");
        break;
    default:
        printf("State unknown\n");
        break;
    }
}

char *err2str(int err)
{
    switch (err)
    {
    case OMX_ErrorInsufficientResources:
        return "OMX_ErrorInsufficientResources";
    case OMX_ErrorUndefined:
        return "OMX_ErrorUndefined";
    case OMX_ErrorInvalidComponentName:
        return "OMX_ErrorInvalidComponentName";
    case OMX_ErrorComponentNotFound:
        return "OMX_ErrorComponentNotFound";
    case OMX_ErrorInvalidComponent:
        return "OMX_ErrorInvalidComponent";
    case OMX_ErrorBadParameter:
        return "OMX_ErrorBadParameter";
    case OMX_ErrorNotImplemented:
        return "OMX_ErrorNotImplemented";
    case OMX_ErrorUnderflow:
        return "OMX_ErrorUnderflow";
    case OMX_ErrorOverflow:
        return "OMX_ErrorOverflow";
    case OMX_ErrorHardware:
        return "OMX_ErrorHardware";
    case OMX_ErrorInvalidState:
        return "OMX_ErrorInvalidState";
    case OMX_ErrorStreamCorrupt:
        return "OMX_ErrorStreamCorrupt";
    case OMX_ErrorPortsNotCompatible:
        return "OMX_ErrorPortsNotCompatible";
    case OMX_ErrorResourcesLost:
        return "OMX_ErrorResourcesLost";
    case OMX_ErrorNoMore:
        return "OMX_ErrorNoMore";
    case OMX_ErrorVersionMismatch:
        return "OMX_ErrorVersionMismatch";
    case OMX_ErrorNotReady:
        return "OMX_ErrorNotReady";
    case OMX_ErrorTimeout:
        return "OMX_ErrorTimeout";
    case OMX_ErrorSameState:
        return "OMX_ErrorSameState";
    case OMX_ErrorResourcesPreempted:
        return "OMX_ErrorResourcesPreempted";
    case OMX_ErrorPortUnresponsiveDuringAllocation:
        return "OMX_ErrorPortUnresponsiveDuringAllocation";
    case OMX_ErrorPortUnresponsiveDuringDeallocation:
        return "OMX_ErrorPortUnresponsiveDuringDeallocation";
    case OMX_ErrorPortUnresponsiveDuringStop:
        return "OMX_ErrorPortUnresponsiveDuringStop";
    case OMX_ErrorIncorrectStateTransition:
        return "OMX_ErrorIncorrectStateTransition";
    case OMX_ErrorIncorrectStateOperation:
        return "OMX_ErrorIncorrectStateOperation";
    case OMX_ErrorUnsupportedSetting:
        return "OMX_ErrorUnsupportedSetting";
    case OMX_ErrorUnsupportedIndex:
        return "OMX_ErrorUnsupportedIndex";
    case OMX_ErrorBadPortIndex:
        return "OMX_ErrorBadPortIndex";
    case OMX_ErrorPortUnpopulated:
        return "OMX_ErrorPortUnpopulated";
    case OMX_ErrorComponentSuspended:
        return "OMX_ErrorComponentSuspended";
    case OMX_ErrorDynamicResourcesUnavailable:
        return "OMX_ErrorDynamicResourcesUnavailable";
    case OMX_ErrorMbErrorsInFrame:
        return "OMX_ErrorMbErrorsInFrame";
    case OMX_ErrorFormatNotDetected:
        return "OMX_ErrorFormatNotDetected";
    case OMX_ErrorContentPipeOpenFailed:
        return "OMX_ErrorContentPipeOpenFailed";
    case OMX_ErrorContentPipeCreationFailed:
        return "OMX_ErrorContentPipeCreationFailed";
    case OMX_ErrorSeperateTablesUsed:
        return "OMX_ErrorSeperateTablesUsed";
    case OMX_ErrorTunnelingUnsupported:
        return "OMX_ErrorTunnelingUnsupported";
    default:
        return "unknown error";
    }
}

void print_port_info(OMX_HANDLETYPE handle, int portindex)
{

    OMX_PARAM_PORTDEFINITIONTYPE portdef;
    memset(&portdef, 0, sizeof(OMX_PARAM_PORTDEFINITIONTYPE));
    portdef.nSize = sizeof(OMX_PARAM_PORTDEFINITIONTYPE);
    portdef.nVersion.nVersion = OMX_VERSION;
    portdef.nPortIndex = portindex;

    OMX_GetParameter(handle,
                     OMX_IndexParamPortDefinition,
                     &portdef);
    char *domain;

    printf("Port %d\n", portdef.nPortIndex);
    if (portdef.eDir == OMX_DirInput)
    {
        printf("  is input port\n");
    }
    else
    {
        printf("  is output port\n");
    }

    switch (portdef.eDomain)
    {
    case OMX_PortDomainAudio:
        domain = "Audio";
        break;
    case OMX_PortDomainVideo:
        domain = "Video";
        break;
    case OMX_PortDomainImage:
        domain = "Image";
        break;
    case OMX_PortDomainOther:
        domain = "Other";
        break;
    }
    printf("  Domain is %s\n", domain);

    printf("  Buffer count %d\n", portdef.nBufferCountActual);
    printf("  Buffer minimum count %d\n", portdef.nBufferCountMin);
    printf("  Buffer size %d bytes\n", portdef.nBufferSize);
    printf("  Enabled %d\n", portdef.bEnabled);
    printf("  Populated %d\n", portdef.bPopulated);

    if (portdef.eDomain == OMX_PortDomainVideo)
        printf("Frame width %d, frame height %d, stride %d, slice height %d\n",
           portdef.format.video.nFrameWidth,
           portdef.format.video.nFrameHeight,
           portdef.format.video.nStride,
           portdef.format.video.nSliceHeight);

    if (portdef.eDomain == OMX_PortDomainImage)
        printf("Frame width %d, frame height %d, stride %d, slice height %d\n",
           portdef.format.image.nFrameWidth,
           portdef.format.image.nFrameHeight,
           portdef.format.image.nStride,
           portdef.format.image.nSliceHeight);

}

void eos_callback(void *userdata, COMPONENT_T *comp, OMX_U32 data)
{
    fprintf(stderr, "Got eos event\n");
}

void error_callback(void *userdata, COMPONENT_T *comp, OMX_U32 data)
{
    fprintf(stderr, "OMX error %s\n", err2str(data));
}

int get_file_size(char *fname)
{
    struct stat st;

    if (stat(fname, &st) == -1)
    {
        perror("Stat'ing img file");
        return -1;
    }
    return (st.st_size);
}

unsigned int uWidth;
unsigned int uHeight;

OMX_ERRORTYPE read_into_buffer_and_empty(FILE *fp,
                                         COMPONENT_T *component,
                                         OMX_BUFFERHEADERTYPE *buff_header,
                                         int *toread)
{
    OMX_ERRORTYPE r;

    int buff_size = buff_header->nAllocLen;
    int nread = fread(buff_header->pBuffer, 1, buff_size, fp);

    buff_header->nFilledLen = nread;
    *toread -= nread;
    printf("Read %d, %d still left\n", nread, *toread);

    if (*toread <= 0)
    {
        printf("Setting EOS on input\n");
        buff_header->nFlags |= OMX_BUFFERFLAG_EOS;
    }
    r = OMX_EmptyThisBuffer(ilclient_get_handle(component),
                            buff_header);
    if (r != OMX_ErrorNone)
    {
        fprintf(stderr, "Empty buffer error %s\n",
                err2str(r));
    }
    return r;
}

static void set_video_decoder_input_format(COMPONENT_T *component)
{
    int err;

    // set input video format
    printf("Setting video decoder format\n");
    OMX_VIDEO_PARAM_PORTFORMATTYPE videoPortFormat;
    //setHeader(&videoPortFormat,  sizeof(OMX_VIDEO_PARAM_PORTFORMATTYPE));
    memset(&videoPortFormat, 0, sizeof(OMX_VIDEO_PARAM_PORTFORMATTYPE));
    videoPortFormat.nSize = sizeof(OMX_VIDEO_PARAM_PORTFORMATTYPE);
    videoPortFormat.nVersion.nVersion = OMX_VERSION;

    videoPortFormat.nPortIndex = 130;
    videoPortFormat.eCompressionFormat = OMX_VIDEO_CodingMPEG2;
    //    videoPortFormat.eCompressionFormat = OMX_VIDEO_CodingAVC;

    err = OMX_SetParameter(ilclient_get_handle(component),
                           OMX_IndexParamVideoPortFormat, &videoPortFormat);
    if (err != OMX_ErrorNone)
    {
        fprintf(stderr, "Error setting video decoder format %s\n", err2str(err));
        return; // err;
    }
    else
    {
        printf("Video decoder format set up ok\n");
    }
}

static void setup_deinterlace(COMPONENT_T *component)
{
    int err;

    // add extra buffers for Advanced Deinterlace
    printf("Setting deinterlace\n");

    OMX_PARAM_U32TYPE extra_buffers;
    memset(&extra_buffers, 0, sizeof(OMX_PARAM_U32TYPE));
    extra_buffers.nSize = sizeof(OMX_PARAM_U32TYPE);
    extra_buffers.nVersion.nVersion = OMX_VERSION;
    extra_buffers.nU32 = 3;
    err = OMX_SetParameter(ilclient_get_handle(component), 
        OMX_IndexParamBrcmExtraBuffers, &extra_buffers);

    OMX_CONFIG_IMAGEFILTERPARAMSTYPE image_filter;
    memset(&image_filter, 0, sizeof(OMX_CONFIG_IMAGEFILTERPARAMSTYPE));
    image_filter.nSize = sizeof(OMX_CONFIG_IMAGEFILTERPARAMSTYPE);
    image_filter.nVersion.nVersion = OMX_VERSION;
    image_filter.nPortIndex = 191;

    image_filter.nNumParams = 1;
    image_filter.nParams[0] = 3;

    image_filter.eImageFilter = OMX_ImageFilterDeInterlaceAdvanced;

    if (err == OMX_ErrorNone)
        err = OMX_SetConfig(ilclient_get_handle(component),
            OMX_IndexConfigCommonImageFilterParameters, &image_filter);

    if (err != OMX_ErrorNone)
    {
        fprintf(stderr, "Error setting deinterlace %s\n", err2str(err));
        return; // err;
    }
    else
    {
        printf("Deinterlace set up ok\n");
    }
}

void setup_decodeComponent(ILCLIENT_T *handle,
                           char *decodeComponentName,
                           COMPONENT_T **decodeComponent)
{
    int err;

    err = ilclient_create_component(handle,
                                    decodeComponent,
                                    decodeComponentName,
                                    ILCLIENT_DISABLE_ALL_PORTS |
                                        ILCLIENT_ENABLE_INPUT_BUFFERS |
                                        ILCLIENT_ENABLE_OUTPUT_BUFFERS);
    if (err == -1)
    {
        fprintf(stderr, "DecodeComponent create failed\n");
        exit(1);
    }
    printState(ilclient_get_handle(*decodeComponent));

    err = ilclient_change_component_state(*decodeComponent,
                                          OMX_StateIdle);
    if (err < 0)
    {
        fprintf(stderr, "Couldn't change state to Idle\n");
        exit(1);
    }
    printState(ilclient_get_handle(*decodeComponent));

    // must be before we enable buffers
    set_video_decoder_input_format(*decodeComponent);
}

void setup_renderComponent(ILCLIENT_T *handle,
                           char *renderComponentName,
                           COMPONENT_T **renderComponent)
{
    int err;

    err = ilclient_create_component(handle,
                                    renderComponent,
                                    renderComponentName,
                                    ILCLIENT_DISABLE_ALL_PORTS |
                                        ILCLIENT_ENABLE_INPUT_BUFFERS);
    if (err == -1)
    {
        fprintf(stderr, "RenderComponent create failed\n");
        exit(1);
    }
    printState(ilclient_get_handle(*renderComponent));

    err = ilclient_change_component_state(*renderComponent,
                                          OMX_StateIdle);
    if (err < 0)
    {
        fprintf(stderr, "Couldn't change state to Idle\n");
        exit(1);
    }
    printState(ilclient_get_handle(*renderComponent));
}

void setup_fxComponent(ILCLIENT_T *handle,
                       char *fxComponentName,
                       COMPONENT_T **fxComponent)
{
    int err;

    err = ilclient_create_component(handle,
                                    fxComponent,
                                    fxComponentName,
                                    ILCLIENT_DISABLE_ALL_PORTS |
                                        ILCLIENT_ENABLE_INPUT_BUFFERS |
                                        ILCLIENT_ENABLE_OUTPUT_BUFFERS);
    if (err == -1)
    {
        fprintf(stderr, "fxComponent create failed\n");
        exit(1);
    }
    printState(ilclient_get_handle(*fxComponent));

    err = ilclient_change_component_state(*fxComponent,
                                          OMX_StateIdle);
    if (err < 0)
    {
        fprintf(stderr, "Couldn't change state to Idle\n");
        exit(1);
    }
    printState(ilclient_get_handle(*fxComponent));

    // must be before we enable buffers
    setup_deinterlace(*fxComponent);
}

void setup_shared_buffer_format(COMPONENT_T *decodeComponent, int decodePort,
                               COMPONENT_T *renderComponent, int renderPort)
{
    OMX_PARAM_PORTDEFINITIONTYPE portdef, rportdef;
    ;
    int ret;
    OMX_ERRORTYPE err;

    // need to setup the input for the render with the output of the
    // decoder
    portdef.nSize = sizeof(OMX_PARAM_PORTDEFINITIONTYPE);
    portdef.nVersion.nVersion = OMX_VERSION;
    portdef.nPortIndex = decodePort;
    OMX_GetParameter(ilclient_get_handle(decodeComponent),
                     OMX_IndexParamPortDefinition, &portdef);

    // Get default values of render
    rportdef.nSize = sizeof(OMX_PARAM_PORTDEFINITIONTYPE);
    rportdef.nVersion.nVersion = OMX_VERSION;
    rportdef.nPortIndex = renderPort;
//    rportdef.nBufferSize = portdef.nBufferSize;
//    nBufferSize = portdef.nBufferSize;

    err = OMX_GetParameter(ilclient_get_handle(renderComponent),
                           OMX_IndexParamPortDefinition, &rportdef);
    if (err != OMX_ErrorNone)
    {
        fprintf(stderr, "Error getting render port params %s\n", err2str(err));
        exit(1);
    }

    // tell render input what the decoder output will be providing
    //Copy some
    rportdef.format.video.nFrameWidth = portdef.format.image.nFrameWidth;
    rportdef.format.video.nFrameHeight = portdef.format.image.nFrameHeight;
    rportdef.format.video.nStride = portdef.format.image.nStride;
    rportdef.format.video.nSliceHeight = portdef.format.image.nSliceHeight;

    err = OMX_SetParameter(ilclient_get_handle(renderComponent),
                           OMX_IndexParamPortDefinition, &rportdef);
    if (err != OMX_ErrorNone)
    {
        fprintf(stderr, "Error setting render port params %s\n", err2str(err));
        exit(1);
    }
    else
    {
        printf("Render port params set up ok\n");
    }

}


int main(int argc, char **argv)
{

    int i;
    char *decodeComponentName;
    char *renderComponentName;
    int err;
    ILCLIENT_T *handle;
    COMPONENT_T *decodeComponent;
    COMPONENT_T *renderComponent;
    COMPONENT_T *fxComponent;
    int do_deinterlace = 0;

    if (argc >= 2)
    {
        IMG = argv[1];
    }
    if (argc >= 3)
    {
        if (strcmp(argv[2],"d")==0)
            do_deinterlace = 1;
    }

    FILE *fp = fopen(IMG, "r");
    int toread = get_file_size(IMG);
    OMX_BUFFERHEADERTYPE *buff_header;

    decodeComponentName = "video_decode";
    renderComponentName = "video_render";

    bcm_host_init();

    handle = ilclient_init();
    if (handle == NULL)
    {
        fprintf(stderr, "IL client init failed\n");
        exit(1);
    }

    if (OMX_Init() != OMX_ErrorNone)
    {
        ilclient_destroy(handle);
        fprintf(stderr, "OMX init failed\n");
        exit(1);
    }

    ilclient_set_error_callback(handle,
                                error_callback,
                                NULL);
    ilclient_set_eos_callback(handle,
                              eos_callback,
                              NULL);

    setup_decodeComponent(handle, decodeComponentName, &decodeComponent);
    setup_renderComponent(handle, renderComponentName, &renderComponent);
    if (do_deinterlace)
        setup_fxComponent(handle, "image_fx", &fxComponent);
    // both components now in Idle state, no buffers, ports disabled

    // input port
    ilclient_enable_port_buffers(decodeComponent, 130,
                                 NULL, NULL, NULL);
    ilclient_enable_port(decodeComponent, 130);

    err = ilclient_change_component_state(decodeComponent,
                                          OMX_StateExecuting);
    if (err < 0)
    {
        fprintf(stderr, "Couldn't change state to Executing\n");
        exit(1);
    }
    printState(ilclient_get_handle(decodeComponent));

    // Read the first block so that the decodeComponent can get
    // the dimensions of the video and call port settings
    // changed on the output port to configure it
    while (toread > 0)
    {
        buff_header =
            ilclient_get_input_buffer(decodeComponent,
                                      130,
                                      1 /* block */);
        if (buff_header != NULL)
        {
            read_into_buffer_and_empty(fp,
                                       decodeComponent,
                                       buff_header,
                                       &toread);

            // If all the file has been read in, then
            // we have to re-read this first block.
            // Broadcom bug?
            if (toread <= 0)
            {
                printf("Rewinding\n");
                // wind back to start and repeat
                fp = freopen(IMG, "r", fp);
                toread = get_file_size(IMG);
            }
        }

        if (toread > 0 && ilclient_remove_event(decodeComponent, OMX_EventPortSettingsChanged, 131, 0, 0, 1) == 0)
        {
            printf("Removed port settings event\n");
            break;
        }
        else
        {
            printf("No port setting seen yet\n");
        }
        // wait for first input block to set params for output port
        if (toread == 0)
        {
            // wait for first input block to set params for output port
            err = ilclient_wait_for_event(decodeComponent,
                                          OMX_EventPortSettingsChanged,
                                          131, 0, 0, 1,
                                          ILCLIENT_EVENT_ERROR | ILCLIENT_PARAMETER_CHANGED,
                                          2000);
            if (err < 0)
            {
                fprintf(stderr, "No port settings change\n");
                //exit(1);
            }
            else
            {
                printf("Port settings changed\n");
                break;
            }
        }
    }

    // set the decode component to idle and disable its ports
    err = ilclient_change_component_state(decodeComponent,
                                          OMX_StateIdle);
    if (err < 0)
    {
        fprintf(stderr, "Couldn't change state to Idle\n");
        exit(1);
    }
    ilclient_disable_port(decodeComponent, 131);
    ilclient_disable_port_buffers(decodeComponent, 131,
                                  NULL, NULL, NULL);

    if (do_deinterlace)
    {
        // set up the tunnel between decode and fx ports
        err = OMX_SetupTunnel(ilclient_get_handle(decodeComponent),
                            131,
                            ilclient_get_handle(fxComponent),
                            190);
        if (err != OMX_ErrorNone)
        {
            fprintf(stderr, "Error setting up tunnel 1 %X\n", err);
            exit(1);
        }
        else
        {
            printf("Tunnel 1 set up ok\n");
        }

        // set up the tunnel between fx and render ports
        err = OMX_SetupTunnel(ilclient_get_handle(fxComponent),
                            191,
                            ilclient_get_handle(renderComponent),
                            90);
        if (err != OMX_ErrorNone)
        {
            fprintf(stderr, "Error setting up tunnel 2 %X\n", err);
            exit(1);
        }
        else
        {
            printf("Tunnel 2 set up ok\n");
        }
    }
    else
    {
        // set up the tunnel between decode and render ports
        err = OMX_SetupTunnel(ilclient_get_handle(decodeComponent),
                            131,
                            ilclient_get_handle(renderComponent),
                            90);
        if (err != OMX_ErrorNone)
        {
            fprintf(stderr, "Error setting up tunnel %X\n", err);
        exit(1);
        }
        else
        {
            printf("Tunnel set up ok\n");
        }
    }
    // Okay to go back to processing data
    // enable the decode output ports

//UNNECESSARY?? PGB    OMX_SendCommand(ilclient_get_handle(decodeComponent),
//UNNECESSARY?? PGB                    OMX_CommandPortEnable, 131, NULL);

    ilclient_enable_port(decodeComponent, 131);

    if (do_deinterlace)
    {
        setup_shared_buffer_format(decodeComponent, 131, fxComponent, 191);
        // enable fx ports
        ilclient_enable_port(fxComponent, 190);
        ilclient_enable_port(fxComponent, 191);

//UNNECESSARY?? PGB    OMX_SendCommand(ilclient_get_handle(renderComponent),
//UNNECESSARY?? PGB                    OMX_CommandPortEnable, 90, NULL);

        // setup_shared_buffer_format(fxComponent, renderComponent);
    }
    // enable the render output ports
    ilclient_enable_port(renderComponent, 90);

    // set all components to executing state
    err = ilclient_change_component_state(decodeComponent,
                                          OMX_StateExecuting);
    if (err < 0)
    {
        fprintf(stderr, "Couldn't change decode to Executing\n");
        exit(1);
    }
    if (do_deinterlace)
    {
        err = ilclient_change_component_state(fxComponent,
                                            OMX_StateExecuting);
        if (err < 0)
        {
            fprintf(stderr, "Couldn't change fx to Executing\n");
            exit(1);
        }
    }
    err = ilclient_change_component_state(renderComponent,
                                          OMX_StateExecuting);
    if (err < 0)
    {
        fprintf(stderr, "Couldn't change render to Executing\n");
        exit(1);
    }

    print_port_info(ilclient_get_handle(decodeComponent), 131);
    if (do_deinterlace)
    {
        print_port_info(ilclient_get_handle(fxComponent), 190);
        print_port_info(ilclient_get_handle(fxComponent), 191);
    }
    print_port_info(ilclient_get_handle(renderComponent), 90);

    // now work through the file
    while (toread > 0)
    {
        OMX_ERRORTYPE r;

        // do we have a decode input buffer we can fill and empty?
        buff_header =
            ilclient_get_input_buffer(decodeComponent,
                                      130,
                                      1 /* block */);
        if (buff_header != NULL)
        {
            read_into_buffer_and_empty(fp,
                                       decodeComponent,
                                       buff_header,
                                       &toread);
        }
        usleep(100000);
        // print_port_info(ilclient_get_handle(renderComponent), 90);
    }


    ilclient_wait_for_event(renderComponent,
                            OMX_EventBufferFlag,
                            90, 0, OMX_BUFFERFLAG_EOS, 0,
                            ILCLIENT_BUFFER_FLAG_EOS, 10000);
    printf("EOS on render\n");

    sleep(100);

    exit(0);
}
