// Free surfaces when leaving room or destroying object
if (surface_exists(surf_reflection)) surface_free(surf_reflection);
if (surface_exists(surf_temp_reflection)) surface_free(surf_temp_reflection);